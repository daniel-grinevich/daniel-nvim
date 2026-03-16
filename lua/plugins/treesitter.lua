require("nvim-treesitter").setup({
  install_dir = vim.fn.stdpath('data') .. '/site',
})

require("nvim-treesitter").install({
  "c",
  "lua",
  "python",
  "javascript",
  "query",
  "typescript",
})

vim.api.nvim_create_autocmd('FileType', {
  callback = function() vim.treesitter.start() end,
})
