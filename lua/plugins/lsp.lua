require("mason").setup()
require("mason-lspconfig").setup({
  ensure_installed = { "pyright", "ruby_lsp", "clangd", "lua_ls", "vue_ls", "ts_ls", "eslint" },
})

vim.lsp.enable("pyright")
vim.lsp.config("ruby_lsp", {
  init_options = {
    formatter = "standard",
    linters = { "standard" },
  },
})
vim.lsp.enable("ruby_lsp")
vim.lsp.enable("clangd")
vim.lsp.enable("lua_ls")

vim.lsp.enable("vue_ls")
local vue_plugin_path = vim.fn.expand(
  "~/.local/share/nvim/mason/packages/vue-language-server/node_modules/@vue/typescript-plugin"
)
vim.lsp.config("ts_ls", {
  filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact", "vue" },
  init_options = {
    plugins = {
      {
        name = "@vue/typescript-plugin",
        location = vue_plugin_path,
        languages = { "vue" },
      },
    },
  },
})
vim.lsp.enable("ts_ls")
vim.lsp.enable("eslint")

vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = { "*.vue", "*.ts", "*.tsx", "*.js", "*.jsx" },
  command = "silent! EslintFixAll",
})

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local opts = { buffer = args.buf }
    local builtin = require("telescope.builtin")

    vim.keymap.set("n", "gd", builtin.lsp_definitions, opts)
    vim.keymap.set("n", "gr", builtin.lsp_references, opts)
    vim.keymap.set("n", "gi", builtin.lsp_implementations, opts)
    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
    vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
  end,
})
