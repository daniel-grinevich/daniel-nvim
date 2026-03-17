vim.lsp.enable("pyright")
vim.lsp.enable("ruby_lsp")
vim.lsp.enable("clangd")

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
