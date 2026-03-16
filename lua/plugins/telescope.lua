print("loading telescope...")
local telescope = require("telescope")
local builtin = require("telescope.builtin")

telescope.setup({})
vim.keymap.set("n", "<leader>pf", builtin.find_files, { desc = "Find files" })
