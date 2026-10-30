-- gpucomplete: Supermaven-style ghost-text completion against the on-prem GPU
-- gateway (gpu1, glm-5.3-flash). See context.lua for how the prompt is built.
local client = require("daniel.gpucomplete.client")
local context = require("daniel.gpucomplete.context")
local ui = require("daniel.gpucomplete.ui")

local M = {}

local defaults = {
  endpoint = "https://gpu1.dsm.corporatetools.com/v1/completions",
  model = "glm-5.3-flash",
  api_key_env = "LOCAL_AGENT_KEY",
  agent_id = "nvim-gpucomplete",
  agent_surface = "nvim",
  timeout_s = 10,
  max_tokens = 96,
  debounce_ms = 250,
  -- "complete": show the suggestion once it's finished. "stream": draw it as tokens arrive.
  display = "complete",
  -- The gateway allows ~60/min per key; stay under it client-side.
  max_requests_per_minute = 50,
  repo_budget_chars = 160000, -- ~45k tokens of repo, sent once and then cached
  max_file_chars = 40000,
  log_budget_chars = 24000,
  opened_file_chars = 12000,
  max_diff_chars = 6000,
  prefix_chars = 12000,
  suffix_chars = 3000,
  exclude_patterns = {},
  disabled_filetypes = { "gitcommit", "gitrebase", "help" },
  keys = {
    accept = "<C-l>",
    accept_word = "<C-j>",
    accept_line = "<C-k>",
    dismiss = "<C-]>",
    toggle = "<leader>at",
  },
}

local cfg
local enabled = true
local timer
local inflight
local current -- { buf, row, col, text }: suggestion shown at (row, col)
local seen_tick -- changedtick we last reacted to; separates typing from cursor moves
local sent = {} -- request timestamps (ms) within the last minute
local backoff_until = 0
local stats = { requests = 0, last_ms = nil, last_error = nil, last_error_at = 0 }

local function now_ms() return vim.uv.now() end

local function report_error(msg)
  stats.last_error = msg
  -- Surface failures, but at most once a minute so a dead gateway doesn't spam.
  if now_ms() - stats.last_error_at > 60000 then
    stats.last_error_at = now_ms()
    vim.notify("[gpucomplete] " .. msg, vim.log.levels.WARN)
  end
end

local function allow_request()
  if now_ms() < backoff_until then return false end
  local cutoff = now_ms() - 60000
  while sent[1] and sent[1] < cutoff do table.remove(sent, 1) end
  if #sent >= cfg.max_requests_per_minute then return false end
  table.insert(sent, now_ms())
  return true
end

local function cancel()
  if timer then timer:stop() end
  if inflight then inflight.cancel() end
  inflight = nil
end

local function clear()
  cancel()
  ui.clear()
  current = nil
end

local function handle_failure(err)
  if err == "cancelled" then return end
  if err.status == 429 then
    backoff_until = now_ms() + 15000
    report_error("rate limited (429); pausing for 15s")
  elseif err.status == 401 or err.status == 403 then
    backoff_until = now_ms() + 300000
    report_error(("auth failed (%d); is $%s valid? pausing for 5m"):format(err.status, cfg.api_key_env))
  else
    report_error(("request failed (http %s): %s"):format(err.status, err.body))
  end
end

local function cursor_matches(buf, row, col)
  if vim.api.nvim_get_current_buf() ~= buf then return false end
  local r, c = unpack(vim.api.nvim_win_get_cursor(0))
  return r == row and c == col
end

local function request()
  if not enabled or vim.fn.mode() ~= "i" then return end
  local buf = vim.api.nvim_get_current_buf()
  if not context.eligible(buf, cfg) then return end
  if not vim.env[cfg.api_key_env] then
    report_error("$" .. cfg.api_key_env .. " is not set in nvim's environment")
    return
  end
  if not allow_request() then return end

  local req = context.build(buf, 0, cfg)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local started = now_ms()
  stats.requests = stats.requests + 1

  if inflight then inflight.cancel() end
  local handle
  local function show(raw)
    if inflight ~= handle or not cursor_matches(buf, row, col) then return end
    local text = context.finish(raw, req.heal, req.resume)
    if text then
      current = { buf = buf, row = row, col = col, text = text }
      ui.show(buf, row, col, text)
    end
  end
  handle = client.stream(cfg, {
    model = cfg.model,
    prompt = req.prompt,
    max_tokens = cfg.max_tokens,
    temperature = 0,
    stop = req.stops,
  }, function(raw)
    if cfg.display == "stream" then show(raw) end
  end, function(raw, err)
    if err then
      if inflight == handle then inflight = nil end
      return handle_failure(err)
    end
    if cfg.display ~= "stream" then show(raw) end
    if inflight == handle then inflight = nil end
    stats.last_ms = now_ms() - started
    stats.last_error = nil
  end)
  inflight = handle
end

local function schedule_request()
  if not enabled then return end
  if not timer then timer = vim.uv.new_timer() end
  timer:stop()
  timer:start(cfg.debounce_ms, 0, vim.schedule_wrap(request))
end

local function on_text_changed_i()
  local buf = vim.api.nvim_get_current_buf()
  seen_tick = vim.b[buf].changedtick
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  -- Typed through the suggestion: keep the rest instead of asking again.
  if current and current.buf == buf and current.row == row and col > current.col then
    local line = vim.api.nvim_get_current_line()
    local typed = line:sub(current.col + 1, col)
    if vim.startswith(current.text, typed) and #typed < #current.text then
      cancel()
      current.text = current.text:sub(#typed + 1)
      current.col = col
      ui.show(buf, row, col, current.text)
      return
    end
  end
  if current and cursor_matches(current.buf, current.row, current.col) then return end
  ui.clear()
  current = nil
  cancel()
  schedule_request()
end

local function on_cursor_moved_i()
  local buf = vim.api.nvim_get_current_buf()
  if vim.b[buf].changedtick ~= seen_tick then return end -- a text change; TextChangedI handles it
  if current and cursor_matches(current.buf, current.row, current.col) then return end
  ui.clear()
  current = nil
  cancel()
  schedule_request()
end

local function take(kind)
  local text = current.text
  if kind == "word" then
    return text:match("^%s*[%w_]+") or text:match("^%s*[^%w_%s]+") or text
  elseif kind == "line" then
    return text:match("^\n[^\n]*") or text:match("^[^\n]*")
  end
  return text
end

local function accept(kind)
  if not current or not cursor_matches(current.buf, current.row, current.col) then return end
  local buf, row, col = current.buf, current.row, current.col
  local chunk = take(kind)
  local rest = current.text:sub(#chunk + 1)
  local lines = vim.split(chunk, "\n", { plain = true })
  cancel()
  ui.clear()
  vim.api.nvim_buf_set_text(buf, row - 1, col, row - 1, col, lines)
  local new_row = row + #lines - 1
  local new_col = #lines == 1 and col + #lines[1] or #lines[#lines]
  vim.api.nvim_win_set_cursor(0, { new_row, new_col })
  seen_tick = vim.b[buf].changedtick
  if rest ~= "" then
    current = { buf = buf, row = new_row, col = new_col, text = rest }
    ui.show(buf, new_row, new_col, rest)
  else
    current = nil
  end
end

local function map_accept(lhs, kind)
  if not lhs then return end
  vim.keymap.set("i", lhs, function()
    if current then
      vim.schedule(function() accept(kind) end)
      return ""
    end
    return lhs
  end, { expr = true, desc = "gpucomplete: accept " .. kind })
end

function M.toggle()
  enabled = not enabled
  if not enabled then clear() end
  vim.notify("[gpucomplete] " .. (enabled and "enabled" or "disabled"))
end

function M.status()
  local st = context.block_for(vim.api.nvim_get_current_buf())
  local lines = {
    ("enabled: %s   model: %s   display: %s"):format(enabled, cfg.model, cfg.display),
    ("key ($%s): %s"):format(cfg.api_key_env, vim.env[cfg.api_key_env] and "set" or "MISSING"),
    ("requests this session: %d   last minute: %d   last latency: %s"):format(
      stats.requests, #sent, stats.last_ms and (stats.last_ms .. "ms") or "-"),
    st and ("repo: %s   block: %d files / %d chars   edit log: %d entries / %d chars%s"):format(
      st.root, st.block_files, #st.block, #st.log, st.log_chars, st.ready and "" or " (building)")
      or "repo: none (buffer not in a git repo)",
    "last error: " .. (stats.last_error or "none"),
  }
  vim.notify(table.concat(lines, "\n"))
end

local function prewarm(st)
  -- One request to put the repo block in vLLM's prefix cache before you type.
  if not enabled or not vim.env[cfg.api_key_env] or not allow_request() then return end
  stats.requests = stats.requests + 1
  client.stream(cfg, { model = cfg.model, prompt = st.block, max_tokens = 1 }, function() end,
    function(_, err)
      if err then handle_failure(err) end
    end)
end

function M.setup(opts)
  cfg = vim.tbl_deep_extend("force", defaults, opts or {})
  vim.api.nvim_set_hl(0, "GpuCompleteSuggestion", { link = "Comment", default = true })

  local group = vim.api.nvim_create_augroup("gpucomplete", { clear = true })
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function(a)
      if context.eligible(a.buf, cfg) then context.enter(a.buf, cfg, prewarm) end
    end,
  })
  vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged", "BufLeave", "BufWritePost" }, {
    group = group,
    callback = function(a)
      if a.event == "InsertLeave" or a.event == "BufLeave" then clear() end
      if context.eligible(a.buf, cfg) then context.record_edit(a.buf, cfg) end
    end,
  })
  vim.api.nvim_create_autocmd("InsertEnter", {
    group = group,
    callback = function(a)
      seen_tick = vim.b[a.buf].changedtick
      schedule_request()
    end,
  })
  vim.api.nvim_create_autocmd("TextChangedI", { group = group, callback = on_text_changed_i })
  vim.api.nvim_create_autocmd("CursorMovedI", { group = group, callback = on_cursor_moved_i })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    callback = function(a) context.forget(a.buf) end,
  })

  map_accept(cfg.keys.accept, "all")
  map_accept(cfg.keys.accept_word, "word")
  map_accept(cfg.keys.accept_line, "line")
  if cfg.keys.dismiss then
    vim.keymap.set("i", cfg.keys.dismiss, clear, { desc = "gpucomplete: dismiss" })
  end
  if cfg.keys.toggle then
    vim.keymap.set("n", cfg.keys.toggle, M.toggle, { desc = "gpucomplete: toggle" })
  end

  vim.api.nvim_create_user_command("GpuComplete", function(c)
    local sub = c.fargs[1] or "status"
    if sub == "toggle" then
      M.toggle()
    elseif sub == "display" then
      cfg.display = cfg.display == "stream" and "complete" or "stream"
      vim.notify("[gpucomplete] display: " .. cfg.display)
    elseif sub == "reload" then
      clear()
      context.reset()
      local buf = vim.api.nvim_get_current_buf()
      if context.eligible(buf, cfg) then context.enter(buf, cfg, prewarm) end
      vim.notify("[gpucomplete] rebuilding repo context")
    else
      M.status()
    end
  end, {
    nargs = "?",
    complete = function() return { "status", "toggle", "display", "reload" } end,
  })
end

-- Exposed for headless testing.
M._request = request
M._current = function() return current end
M._accept = accept
M._on_text_changed_i = on_text_changed_i
M._context = context

return M
