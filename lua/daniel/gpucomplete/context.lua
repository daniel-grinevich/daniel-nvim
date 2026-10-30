-- Supermaven-style context: a frozen repo block, an append-only edit log, then
-- the current file. Everything before the current file only ever grows at the
-- end, so vLLM's prefix cache reuses it and each request only prefills the tail.
local M = {}

local roots = {} -- root path -> state
local by_buf = {} -- bufnr -> { root = string|false, rel = string }

local TEXT_EXT = {}
for ext in ([[lua ts tsx js jsx mjs cjs vue svelte py rb erb rake go rs c h cc cpp hpp java kt
  swift cs php sh zsh bash sql graphql gql css scss html md yml yaml toml ex exs]]):gmatch("%S+") do
  TEXT_EXT[ext] = true
end

local SKIP = {
  "lock%.json$", "%.lock$", "%-lock%.ya?ml$", "%.min%.", "%.snap$", "%.generated%.",
  "^dist/", "/dist/", "^build/", "^vendor/", "node_modules/", "^coverage/", "^public/",
}

local function header(rel, note)
  return "// ===== " .. rel .. (note and (" (" .. note .. ")") or "") .. " =====\n"
end

local function wanted(rel, cfg)
  local ext = rel:match("%.([%w]+)$")
  if not ext or not TEXT_EXT[ext:lower()] then return false end
  for _, pat in ipairs(SKIP) do
    if rel:find(pat) then return false end
  end
  for _, pat in ipairs(cfg.exclude_patterns) do
    if rel:find(pat) then return false end
  end
  return true
end

local function shared_depth(a, b)
  local n = 0
  local pa, pb = vim.split(a, "/", { plain = true }), vim.split(b, "/", { plain = true })
  for i = 1, math.min(#pa, #pb) - 1 do
    if pa[i] ~= pb[i] then break end
    n = n + 1
  end
  return n
end

local function read_file(path, max_chars)
  local f = io.open(path, "r")
  if not f then return nil end
  local s = f:read(max_chars + 1)
  f:close()
  if not s or #s > max_chars or s:find("\0", 1, true) then return nil end
  return s
end

local function buf_text(buf)
  return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end

local function append_log(st, entry, cfg)
  table.insert(st.log, entry)
  st.log_chars = st.log_chars + #entry
  if st.log_chars > cfg.log_budget_chars then
    -- Trimming breaks the cached prefix once; drop down to half so it's rare.
    while st.log_chars > cfg.log_budget_chars / 2 and #st.log > 0 do
      st.log_chars = st.log_chars - #table.remove(st.log, 1)
    end
  end
end

--- Buffers we complete in: real files only.
function M.eligible(buf, cfg)
  if vim.bo[buf].buftype ~= "" or vim.api.nvim_buf_get_name(buf) == "" then return false end
  return not vim.tbl_contains(cfg.disabled_filetypes, vim.bo[buf].filetype)
end

local function info(buf)
  local i = by_buf[buf]
  if i then return i end
  local name = vim.api.nvim_buf_get_name(buf)
  local root = vim.fs.root(buf, ".git")
  i = { root = root or false, rel = root and name:sub(#root + 2) or vim.fn.fnamemodify(name, ":t") }
  by_buf[buf] = i
  return i
end

local function build_block(st, anchor_rel, cfg, on_ready)
  vim.system({ "git", "ls-files", "-z" }, { cwd = st.root, text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        st.error = "git ls-files failed: " .. vim.trim(res.stderr or "")
        vim.notify("[gpucomplete] " .. st.error, vim.log.levels.WARN)
        return
      end
      local files = {}
      for rel in (res.stdout or ""):gmatch("[^%z]+") do
        if wanted(rel, cfg) then table.insert(files, rel) end
      end
      -- Nearest to the file you opened first; frozen afterwards so the prefix stays byte-identical.
      table.sort(files, function(a, b)
        local da, db = shared_depth(a, anchor_rel), shared_depth(b, anchor_rel)
        if da ~= db then return da > db end
        return a < b
      end)
      local parts, used = {}, 0
      for _, rel in ipairs(files) do
        if used >= cfg.repo_budget_chars then break end
        local content = read_file(st.root .. "/" .. rel, cfg.max_file_chars)
        if content then
          local piece = header(rel) .. content .. "\n\n"
          if used + #piece <= cfg.repo_budget_chars then
            table.insert(parts, piece)
            st.in_block[rel] = true
            used = used + #piece
          end
        end
      end
      st.block = table.concat(parts)
      st.block_files = vim.tbl_count(st.in_block)
      st.ready = true
      on_ready(st)
    end)
  end)
end

--- Call on BufEnter. on_block_ready(state) fires once per repo when its block is built.
function M.enter(buf, cfg, on_block_ready)
  local i = info(buf)
  if not i.root then return end
  local st = roots[i.root]
  if not st then
    st = { root = i.root, block = "", in_block = {}, block_files = 0, log = {}, log_chars = 0,
      snapshots = {}, opened = {}, ready = false }
    roots[i.root] = st
    build_block(st, i.rel, cfg, on_block_ready)
  end
  if st.snapshots[buf] == nil then st.snapshots[buf] = buf_text(buf) end
  -- Files outside the repo block get added to the log once, the first time you open them.
  if st.ready and not st.in_block[i.rel] and not st.opened[i.rel] then
    st.opened[i.rel] = true
    local text = st.snapshots[buf]
    append_log(st, header(i.rel, "opened") .. text:sub(1, cfg.opened_file_chars) .. "\n\n", cfg)
  end
end

--- Call after edits settle (InsertLeave, TextChanged, BufLeave, BufWritePost).
--- Appends a unified diff of what changed since the last snapshot.
function M.record_edit(buf, cfg)
  local i = by_buf[buf]
  local st = i and i.root and roots[i.root]
  if not st or st.snapshots[buf] == nil then return end
  local now = buf_text(buf)
  local old = st.snapshots[buf]
  if now == old then return end
  st.snapshots[buf] = now
  local diff = vim.diff(old .. "\n", now .. "\n", { result_type = "unified", ctxlen = 2 })
  if type(diff) ~= "string" or diff == "" or #diff > cfg.max_diff_chars then return end
  if not diff:find("\n[-+]%s*%S") then return end -- whitespace-only change
  append_log(st, header(i.rel, "edit") .. diff .. "\n", cfg)
end

--- Builds the request for the cursor in `win`.
--- Returns { prompt, heal, stops } or nil.
function M.build(buf, win, cfg)
  local i = info(buf)
  local st = i.root and roots[i.root] or nil
  local row, col = unpack(vim.api.nvim_win_get_cursor(win))
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local line = lines[row] or ""

  local before = table.concat(lines, "\n", 1, row - 1)
  before = (row > 1 and before .. "\n" or "") .. line:sub(1, col)
  if #before > cfg.prefix_chars then
    before = before:sub(-cfg.prefix_chars)
    before = before:sub((before:find("\n", 1, true) or 0) + 1)
  end

  local rest_of_line = line:sub(col + 1)
  local after = rest_of_line .. "\n" .. table.concat(lines, "\n", row + 1)
  after = after:sub(1, cfg.suffix_chars)

  -- Token healing: a prompt ending in indentation makes the model emit odd
  -- leading spaces. Send it without the trailing whitespace and strip it back off.
  local heal = before:match("[ \t]+$") or ""
  local prefix = before:sub(1, #before - #heal)

  -- A blank line ends the suggestion: finish this block, don't invent the next function.
  local stops = { "\n// ===== ", "\n\n" }
  -- Multi-line only on an empty line or right after an opener; otherwise finish the statement.
  local typed = line:sub(1, col)
  local opens_block = typed:match("[%{%(%[:]%s*$") or typed:match("=>%s*$")
  if rest_of_line:match("%S") or (typed:match("%S") and not opens_block) then
    table.insert(stops, "\n")
  end
  local resume
  for l in after:sub(#rest_of_line + 2):gmatch("[^\n]+") do
    if l:match("%S") then
      table.insert(stops, "\n" .. l) -- stop where the existing code resumes
      resume = vim.trim(l)
      break
    end
  end

  local parts = {}
  if st and st.ready then
    table.insert(parts, st.block)
    table.insert(parts, table.concat(st.log))
  end
  if after:match("%S") then
    table.insert(parts, header(i.rel, "code after the cursor") .. after .. "\n\n")
  end
  table.insert(parts, header(i.rel) .. prefix)

  return { prompt = table.concat(parts), heal = heal, stops = stops, resume = resume }
end

--- Cleans a raw completion. Returns nil when there is nothing worth showing.
--- `resume` is the next existing line after the cursor (trimmed); the suggestion
--- is cut where it starts repeating it at a different indentation.
function M.finish(text, heal, resume)
  if resume and resume ~= "" then
    local kept = {}
    for idx, l in ipairs(vim.split(text, "\n", { plain = true })) do
      if idx > 1 and vim.trim(l) == resume then break end
      table.insert(kept, l)
    end
    text = table.concat(kept, "\n")
  end
  if heal ~= "" then
    if vim.startswith(text, heal) then
      text = text:sub(#heal + 1)
    elseif not text:match("^\n") then
      text = text:gsub("^[ \t]+", "")
    end
  end
  text = text:gsub("%s+$", "")
  if not text:match("%S") then return nil end
  return text
end

function M.block_for(buf)
  local i = by_buf[buf]
  return i and i.root and roots[i.root] or nil
end

function M.reset()
  roots, by_buf = {}, {}
end

function M.forget(buf)
  local i = by_buf[buf]
  local st = i and i.root and roots[i.root]
  if st then st.snapshots[buf] = nil end
  by_buf[buf] = nil
end

return M
