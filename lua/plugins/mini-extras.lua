-- File-type icons (requires a Nerd Font in your terminal)
local MiniIcons = require("mini.icons")
MiniIcons.setup()
MiniIcons.mock_nvim_web_devicons()

-- File explorer: opens at the current file's directory, not always cwd
require("mini.files").setup({
  windows = { preview = true, width_focus = 30, width_preview = 50 },
})

vim.keymap.set("n", "<leader>pv", function()
  if not MiniFiles.close() then
    MiniFiles.open(vim.api.nvim_buf_get_name(0))
  end
end, { desc = "Files: current file dir" })

vim.keymap.set("n", "<leader>pe", MiniFiles.open, { desc = "Files: project root" })

-- Statusline: shows mode, filename, git branch, diagnostics, position
require("mini.statusline").setup()

-- Auto-close brackets/quotes in insert mode
require("mini.pairs").setup()
