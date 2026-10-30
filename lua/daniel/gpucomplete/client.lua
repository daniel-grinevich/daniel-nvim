-- Streaming client for the on-prem GPU gateway's OpenAI-compatible /v1/completions.
-- The API key is read by curl from the environment (--variable/--expand-header),
-- so it never shows up in argv / `ps`.
local M = {}

local STATUS_MARK = "__GPUCOMPLETE_HTTP__"

local function curl_args(cfg)
  return {
    "curl", "-sS", "-N",
    "--max-time", tostring(cfg.timeout_s),
    "--variable", "%" .. cfg.api_key_env,
    "--expand-header", "Authorization: Bearer {{" .. cfg.api_key_env .. "}}",
    "-H", "Content-Type: application/json",
    "-H", "X-CT-Agent-Id: " .. cfg.agent_id,
    "-H", "X-Agent-Surface: " .. cfg.agent_surface,
    "-w", "\n" .. STATUS_MARK .. "%{http_code}\n",
    "--data-binary", "@-",
    cfg.endpoint,
  }
end

--- Streams a completion.
--- on_text(accumulated_text) is called on the main loop as chunks arrive.
--- on_done(text, err) is called once; err is nil on success, "cancelled" when
--- cancelled, or { status = number, body = string } on failure.
--- Returns a handle with :cancel().
function M.stream(cfg, body, on_text, on_done)
  local acc, pending, errlines = {}, "", {}
  local status
  local finished = false

  local function handle_line(line)
    local code = line:match("^" .. STATUS_MARK .. "(%d+)")
    if code then
      status = tonumber(code)
      return
    end
    local payload = line:match("^data: (.*)")
    if not payload then
      if line ~= "" then table.insert(errlines, line) end
      return
    end
    if payload == "[DONE]" then return end
    local ok, obj = pcall(vim.json.decode, payload)
    local choice = ok and type(obj) == "table" and obj.choices and obj.choices[1]
    if choice and type(choice.text) == "string" and choice.text ~= "" then
      table.insert(acc, choice.text)
      if not finished then on_text(table.concat(acc)) end
    end
  end

  local function feed(data)
    pending = pending .. data
    while true do
      local nl = pending:find("\n", 1, true)
      if not nl then break end
      handle_line((pending:sub(1, nl - 1):gsub("\r$", "")))
      pending = pending:sub(nl + 1)
    end
  end

  body.stream = true
  local proc = vim.system(curl_args(cfg), {
    stdin = vim.json.encode(body),
    stdout = function(_, data)
      if data then vim.schedule(function() feed(data) end) end
    end,
    stderr = function(_, data)
      if data then vim.schedule(function() table.insert(errlines, vim.trim(data)) end) end
    end,
  }, function(res)
    vim.schedule(function()
      if pending ~= "" then handle_line(pending) end
      if finished then return end
      finished = true
      if res.signal ~= 0 then
        on_done(nil, "cancelled")
      elseif res.code ~= 0 or status ~= 200 then
        on_done(nil, { status = status or 0, body = table.concat(errlines, " "):sub(1, 400) })
      else
        on_done(table.concat(acc), nil)
      end
    end)
  end)

  return {
    cancel = function()
      if finished then return end
      finished = true
      -- Killing curl drops the connection, which makes vLLM abort the request
      -- instead of finishing it on the GPU.
      pcall(proc.kill, proc, "sigterm")
    end,
  }
end

return M
