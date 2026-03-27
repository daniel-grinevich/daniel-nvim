require("neo-tree").setup({
  filesystem = {
    hijack_netrw_behavior = "open_current",
    follow_current_file = { enabled = true },
  },
  window = {
    position = "left",
    width = 50,
    mappings = {
      ["l"] = "open",
      ["h"] = "close_node",
    },
  },
})

vim.keymap.set("n", "<leader>pv", "<cmd>Neotree toggle reveal<cr>", { desc = "Files: toggle sidebar (reveal current)" })
vim.keymap.set("n", "<leader>pe", "<cmd>Neotree toggle<cr>", { desc = "Files: toggle sidebar (project root)" })
