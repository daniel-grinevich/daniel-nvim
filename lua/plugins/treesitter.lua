require("nvim-treesitter").setup({
  install_dir = vim.fn.stdpath('data') .. '/site',
})

require("nvim-treesitter").install({
  "c",
  "ruby",
  "lua",
  "python",
  "javascript",
  "query",
  "typescript",
})

vim.api.nvim_create_autocmd('FileType', {
  callback = function() pcall(vim.treesitter.start) end,
})
