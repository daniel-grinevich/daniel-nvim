vim.opt.clipboard = "unnamedplus"

vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.hlsearch = false
vim.opt.incsearch = true
vim.opt.termguicolors = true
vim.opt.updatetime = 50

vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true
-- pane-killed sessions littered 151 stale swaps (2026-10-29); undofile covers recovery
vim.opt.swapfile = false

vim.opt.winbar = "%#WinBarFilename# %t %*"

vim.cmd.colorscheme("tokyonight")

vim.api.nvim_set_hl(0, "WinBarFilename", { bg = "#3b4261", fg = "#c0caf5", bold = true })
