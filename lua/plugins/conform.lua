require("conform").setup({
  formatters_by_ft = {
    lua = { "stylua" },
    python = { "black" },
    ruby = { "standardrb" },
    javascript = { "prettier" },
    typescript = { "prettier" },
  },
  format_on_save = {
    timeout_ms = 500,
    lsp_format = "fallback",
  },
})

vim.keymap.set("n", "<leader>f", function()
  require("conform").format({ async = true, lsp_format = "fallback" })
end, { desc = "Format buffer" })
