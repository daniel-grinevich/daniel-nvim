local dap = require("dap")
local dapui = require("dapui")

-- Log everything to ~/.cache/nvim/dap.log (view with :DapShowLog).
-- Crucial fallback when the console panel looks empty -- shows rdbg spawn
-- args, connection attempts, and adapter errors.
dap.set_log_level("DEBUG")

-- Breakpoint signs: red, prominent, and always visible alongside gitsigns.
-- signcolumn=yes:2 reserves two sign slots per line so a gitsigns marker
-- and a DAP breakpoint can coexist instead of one hiding the other.
vim.opt.signcolumn = "yes:2"

vim.api.nvim_set_hl(0, "DapBreakpoint", { fg = "#FF2A2A", bold = true })
vim.api.nvim_set_hl(0, "DapBreakpointCondition", { fg = "#FFA500", bold = true })
vim.api.nvim_set_hl(0, "DapLogPoint", { fg = "#61AFEF", bold = true })
vim.api.nvim_set_hl(0, "DapStopped", { fg = "#98C379", bold = true })
vim.api.nvim_set_hl(0, "DapBreakpointRejected", { fg = "#888888", bold = true })

vim.fn.sign_define("DapBreakpoint", {
  text = "●",
  texthl = "DapBreakpoint",
  linehl = "",
  numhl = "DapBreakpoint",
})
vim.fn.sign_define("DapBreakpointCondition", {
  text = "◆",
  texthl = "DapBreakpointCondition",
  linehl = "",
  numhl = "DapBreakpointCondition",
})
vim.fn.sign_define("DapLogPoint", {
  text = "◆",
  texthl = "DapLogPoint",
  linehl = "",
  numhl = "DapLogPoint",
})
vim.fn.sign_define("DapStopped", {
  text = "▶",
  texthl = "DapStopped",
  linehl = "DapStoppedLine",
  numhl = "DapStopped",
})
vim.fn.sign_define("DapBreakpointRejected", {
  text = "✗",
  texthl = "DapBreakpointRejected",
  linehl = "",
  numhl = "DapBreakpointRejected",
})

-- Initialize DAP UI and Virtual Text. Bottom tray hosts the repl (the
-- interactive Ruby console you get when a breakpoint hits -- type
-- expressions here and they are evaluated in the paused frame). Rack
-- server stdout is NOT routed through dap-ui; the ruby adapter below
-- spawns rdbg in a separate terminal buffer so boot/request logs are
-- visible live.
dapui.setup({
  layouts = {
    {
      elements = {
        { id = "scopes", size = 0.25 },
        { id = "breakpoints", size = 0.25 },
        { id = "stacks", size = 0.25 },
        { id = "watches", size = 0.25 },
      },
      size = 40,
      position = "left",
    },
    {
      elements = {
        "repl",
      },
      size = 15,
      position = "bottom",
    },
  },
})
require("nvim-dap-virtual-text").setup()

-- Ruby Adapter
--
-- Design notes (this one fought back, so read before editing):
--
-- a. We spawn the debugger in a :terminal buffer instead of letting
--    nvim-dap spawn it via adapter.executable. nvim-dap's spawner
--    (session.lua:spawn_server_executable) pipes stdout/stderr into
--    ~/.cache/nvim/dap-ruby-stdout.log and dap-ruby-stderr.log -- they
--    never reach the dap-ui console or event_output listeners. A
--    termopen buffer gives us live, scrollable output instead.
--
-- b. The `debug` gem (rdbg) is NOT in this project's Gemfile, so
--    `bundle exec rdbg` fails with bundler's gem-enforcement error.
--
-- c. We also can't use `rdbg -c -- bundle exec rackup ...` because rdbg
--    then Kernel.execs the shell command, which in turn spawns a new
--    Ruby process (bundle) that spawns another (rackup). rdbg's
--    $RUBYOPT auto-attach hook fires for each, giving you 2-3
--    overlapping debug sessions on the same port. Symptoms: the first
--    request after attach misses the breakpoint and spawns a "second
--    interactive debug console", the second hits it, and sometimes
--    nothing attaches at all.
--
-- The fix: skip rdbg entirely and run `ruby` directly with
-- RUBYOPT="-rdebug/open -rbundler/setup". Two requires, in order:
--
--   1. `debug/open` -- resolves via rubygems from the global gemset
--      (no bundler restriction yet), loads the full debug gem, and
--      starts a DAP server driven by the RUBY_DEBUG_* env vars below.
--   2. `bundler/setup` -- activates the project Gemfile. $LOAD_PATH is
--      reconfigured to only the bundled gems, but the already-loaded
--      debug code remains live in $LOADED_FEATURES.
--
-- Then ruby runs `-e "load ARGV.shift"` which Kernel.loads the
-- command's binstub (rackup/rails/rspec) in the same process. One Ruby
-- VM, one DAP session, bundled gems available to the app, no exec
-- cascade.
dap.adapters.ruby = function(callback, config)
  local port = math.random(40000, 59999)

  -- Resolve the binstub (rackup/rails/rspec) to an absolute path so we
  -- can Kernel.load it directly. `which` is fine here -- the user's
  -- shell env is the rvm+gemset for this project.
  local resolved = vim.fn.trim(vim.fn.system({ "which", config.command }))
  if vim.v.shell_error ~= 0 or resolved == "" then
    vim.notify(
      "DAP Ruby: could not find `" .. config.command .. "` in PATH",
      vim.log.levels.ERROR
    )
    return
  end

  local env = vim.fn.environ()
  env.BUNDLE_GEMFILE = vim.fn.getcwd() .. "/Gemfile"
  env.RUBY_DEBUG_OPEN = "true"
  env.RUBY_DEBUG_HOST = "127.0.0.1"
  env.RUBY_DEBUG_PORT = tostring(port)
  env.RUBY_DEBUG_NONSTOP = "true"
  env.RUBYOPT = ((env.RUBYOPT or "") .. " -rdebug/open -rbundler/setup"):gsub("^%s+", "")

  local cmd = {
    "ruby",
    "-e", "load ARGV.shift",
    resolved, config.script,
  }

  -- Open a bottom split with a terminal running ruby. Name the buffer
  -- so we can jump back to it, and restore focus to the previous window.
  vim.cmd("botright 15split")
  vim.cmd("enew")
  vim.fn.termopen(cmd, {
    env = env,
    on_exit = function(_, code)
      vim.schedule(function()
        vim.notify("debug process exited with code " .. code, vim.log.levels.INFO, { title = "DAP Ruby" })
      end)
    end,
  })
  vim.api.nvim_buf_set_name(0, "dap-ruby-rdbg")
  vim.bo.buflisted = false
  vim.cmd("wincmd p") -- return focus to the editor window

  -- Give the debug server a moment to bind its TCP port, then tell
  -- nvim-dap to connect.
  vim.defer_fn(function()
    callback({ type = "server", host = "127.0.0.1", port = port })
  end, 800)
end

dap.configurations.ruby = {
  {
    type = "ruby",
    name = "Rails server",
    request = "launch",
    command = "rails",
    script = "server",
  },
  {
    type = "ruby",
    name = "Rack (rackup)",
    request = "launch",
    command = "rackup",
    script = "config.ru",
  },
  {
    type = "ruby",
    name = "RSpec current file",
    request = "launch",
    command = "rspec",
    script = "${file}",
  },
  {
    type = "ruby",
    name = "RSpec current line",
    request = "launch",
    command = "rspec",
    script = "${file}:${line}",
  },
}

-- Python Adapter (debugpy)
dap.adapters.python = function(callback, config)
  callback({
    type = "executable",
    command = "python",
    args = { "-m", "debugpy.adapter" },
  })
end

dap.configurations.python = {
  {
    type = "python",
    request = "launch",
    name = "Launch file",
    program = "${file}",
    pythonPath = function()
      return "python"
    end,
  },
}

-- Keybindings
vim.keymap.set("n", "<leader>b", function()
  dap.toggle_breakpoint()
end, { desc = "DAP: Toggle breakpoint" })

vim.keymap.set("n", "<leader>dc", function()
  dap.continue()
end, { desc = "DAP: Continue" })

vim.keymap.set("n", "<leader>do", function()
  dap.step_over()
end, { desc = "DAP: Step over" })

vim.keymap.set("n", "<leader>di", function()
  dap.step_into()
end, { desc = "DAP: Step into" })

vim.keymap.set("n", "<leader>dO", function()
  dap.step_out()
end, { desc = "DAP: Step out" })

vim.keymap.set("n", "<leader>dr", function()
  dap.repl.open()
end, { desc = "DAP: Open REPL" })

vim.keymap.set("n", "<leader>dl", function()
  dap.run_last()
end, { desc = "DAP: Run last config" })

vim.keymap.set("n", "<leader>du", function()
  dapui.toggle()
end, { desc = "DAP: Toggle UI" })

-- Auto-open/close DAP UI
dap.listeners.after.event_initialized["dapui_config"] = function()
  dapui.open()
end
dap.listeners.before.event_terminated["dapui_config"] = function()
  dapui.close()
end
dap.listeners.before.event_exited["dapui_config"] = function()
  dapui.close()
end

-- Mirror every stdout/stderr output event to vim.notify. Note: with
-- server adapters nvim-dap writes exec stdout to log files, not to
-- event_output -- this listener only fires for output the DAP protocol
-- itself emits (e.g. rdbg writing to session output after attach).
dap.listeners.after.event_output["user_console_mirror"] = function(_, body)
  if body.category == "stdout" or body.category == "stderr" then
    vim.schedule(function()
      vim.notify(body.output, vim.log.levels.INFO, { title = "DAP " .. body.category })
    end)
  end
end

-- When execution pauses at a breakpoint, auto-open the dap REPL so the
-- user can immediately type Ruby expressions against the paused frame.
-- This is the "interactive ruby console" at breakpoints -- dap.repl
-- evaluates input via the DAP `evaluate` request in the current frame.
dap.listeners.after.event_stopped["user_open_repl"] = function()
  vim.schedule(function()
    dap.repl.open()
  end)
end
