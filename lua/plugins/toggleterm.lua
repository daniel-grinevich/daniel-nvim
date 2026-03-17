require("toggleterm").setup({
  size = 15,
  open_mapping = [[<C-\>]],
  direction = "horizontal",
  persist_size = true,
  close_on_exit = true,
})

-- Exit terminal mode with Esc
vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { desc = "Exit terminal mode" })
