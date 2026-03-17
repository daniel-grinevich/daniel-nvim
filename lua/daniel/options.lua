vim.opt.clipboard = "unnamedplus"

vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.hlsearch = false
vim.opt.incsearch = true
vim.opt.termguicolors = true
vim.opt.updatetime = 50

vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true

vim.cmd.colorscheme("tokyonight")
