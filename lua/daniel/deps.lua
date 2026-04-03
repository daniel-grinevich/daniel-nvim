local MiniDeps = require("mini.deps")
MiniDeps.setup()

MiniDeps.add({
  source = "nvim-telescope/telescope.nvim",
  depends = { "nvim-lua/plenary.nvim" }
})

MiniDeps.add({ source = "neovim/nvim-lspconfig" })
MiniDeps.add({ source = "echasnovski/mini.completion" })
MiniDeps.add({ source = "nvim-treesitter/nvim-treesitter" })
MiniDeps.add({ source = "folke/tokyonight.nvim" })

MiniDeps.add({ source = "williamboman/mason.nvim" })
MiniDeps.add({
  source = "williamboman/mason-lspconfig.nvim",
  depends = { "williamboman/mason.nvim", "neovim/nvim-lspconfig" },
})
MiniDeps.add({ source = "stevearc/conform.nvim" })
MiniDeps.add({ source = "j-hui/fidget.nvim" })
MiniDeps.add({ source = "folke/trouble.nvim" })
MiniDeps.add({ source = "christoomey/vim-tmux-navigator" })
MiniDeps.add({
  source = "ThePrimeagen/harpoon",
  checkout = "harpoon2",
  depends = { "nvim-lua/plenary.nvim" },
})
MiniDeps.add({ source = "mbbill/undotree" })
MiniDeps.add({ source = "tpope/vim-fugitive" })
MiniDeps.add({
  source = "nvim-neo-tree/neo-tree.nvim",
  depends = { "nvim-lua/plenary.nvim", "MunifTanjim/nui.nvim" },
})

-- Debug Adapter Protocol (DAP)
MiniDeps.add({ source = "mfussenegger/nvim-dap" })
MiniDeps.add({ source = "nvim-neotest/nvim-nio" })
MiniDeps.add({
  source = "rcarriga/nvim-dap-ui",
  depends = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
})
MiniDeps.add({
  source = "theHamsta/nvim-dap-virtual-text",
  depends = { "mfussenegger/nvim-dap", "nvim-treesitter/nvim-treesitter" },
})
