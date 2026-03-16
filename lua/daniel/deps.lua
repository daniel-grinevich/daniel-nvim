local MiniDeps = require("mini.deps")
MiniDeps.setup()

local add = MiniDeps.add({
  source = "nvim-telescope/telescope.nvim",
  depends = {
    "nvim-lua/plenary.nvim"
  }
})

MiniDeps.add({ source = "neovim/nvim-lspconfig" })
MiniDeps.add({ source = "nvim-treesitter/nvim-treesitter" })
MiniDeps.add({ source = "folke/tokyonight.nvim" })                                                                                                                                                

require("plugins.lsp")
require("plugins.telescope")
require("plugins.treesitter")
