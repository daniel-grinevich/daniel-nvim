local dap = require("dap")
local dapui = require("dapui")

-- Initialize DAP UI and Virtual Text
dapui.setup()
require("nvim-dap-virtual-text").setup()

-- Ruby Adapter (rdbg)
dap.adapters.ruby = function(callback, config)
  callback({
    type = "server",
    host = "127.0.0.1",
    port = "${port}",
    executable = {
      command = "rdbg",
      args = { "-n", "--open", "--port", "${port}", "-c", "--", "bundle", "exec", config.command, config.script },
    },
  })
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
