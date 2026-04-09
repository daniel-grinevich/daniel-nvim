-- File-type icons (requires a Nerd Font in your terminal)
local MiniIcons = require("mini.icons")
MiniIcons.setup()
MiniIcons.mock_nvim_web_devicons()

-- Statusline: shows mode, filename, git branch, diagnostics, position
require("mini.statusline").setup()

-- Auto-close brackets/quotes in insert mode
require("mini.pairs").setup()

-- Git line change signs in the sign column
require("mini.diff").setup({
  view = {
    style = "sign",
  },
})
