vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.wrap = false

vim.keymap.set("n", "<leader>w", "<cmd>w<cr>")
vim.keymap.set("n", "<leader>q", "<cmd>q!<cr>")

-- Move "more" up/down
vim.keymap.set("n", "J", "5j")
vim.keymap.set("n", "K", "5k")
-- Move selected lines up/down in visual mode
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")
-- Restore Join
vim.keymap.set("n", "<leader>j", "J")
-- Join lines but keep cursor in place
vim.keymap.set("n", "J", "mzJ`z")

-- Scroll half-page and keep cursor centered
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")

-- Keep search results centered
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

-- Paste over selection without overwriting clipboard
vim.keymap.set("x", "<leader>p", [["_dP]])

-- Yank to system clipboard
vim.keymap.set({ "n", "v" }, "<leader>y", [["+y]])
vim.keymap.set("n", "<leader>Y", [["+Y]])

-- Delete to void register (don't pollute clipboard)
vim.keymap.set({ "n", "v" }, "<leader>d", [["_d]])

-- Ctrl+C exits insert mode
vim.keymap.set("i", "<C-c>", "<Esc>")

-- Disable Q (accidental macro hell)
vim.keymap.set("n", "Q", "<nop>")

-- Show diagnostic float for current line
vim.keymap.set("n", "gl", vim.diagnostic.open_float)

-- Find and replace word under cursor
vim.keymap.set("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])
