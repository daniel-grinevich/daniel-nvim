local telescope = require("telescope")
local builtin = require("telescope.builtin")

telescope.setup({})

vim.keymap.set("n", "<leader>pf", builtin.find_files, { desc = "Find files" })
vim.keymap.set("n", "<leader>ps", builtin.live_grep, { desc = "Project search (grep)" })
vim.keymap.set("n", "<leader>pb", builtin.buffers, { desc = "Project buffers" })
vim.keymap.set("n", "<leader>pws", builtin.grep_string, { desc = "Search word under cursor" })
