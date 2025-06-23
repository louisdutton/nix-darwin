-- Plugin configuration using lazy.nvim
-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Plugin specifications
require("lazy").setup({
  -- Colorscheme
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      require("catppuccin").setup({
        flavour = "mocha",
        transparent_background = true,
        integrations = {
          gitsigns = true,
          nvimtree = true,
          treesitter = true,
          notify = true,
          noice = true,
          which_key = true,
        },
      })
      vim.cmd.colorscheme("catppuccin")
    end,
  },
  -- LSP and completion
  {
    "neovim/nvim-lspconfig",
  },
  {
    "saghen/blink.cmp",
    dependencies = "rafamadriz/friendly-snippets",
    version = "v0.*",
    opts = {
      keymap = { preset = "super-tab" },
      completion = {
        ghost_text = {
          enabled = false
        },
      },
      appearance = {
        nerd_font_variant = "mono"
      },
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
      },
    },
  },

  -- Fuzzy finder
  {
    "ibhagwan/fzf-lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("fzf-lua").setup({ "fzf-native" })
    end,
  },

  -- File explorer
  {
    "stevearc/oil.nvim",
    config = function()
      require("oil").setup({
        skip_confirm_for_simple_edits = true,
        view_options = {
          show_hidden = true
        }
      })
    end,
  },

  -- Git integration
  {
    "lewis6991/gitsigns.nvim",
    config = function()
      require("gitsigns").setup()
    end,
  },

  -- UI enhancements
  {
    "folke/noice.nvim",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "rcarriga/nvim-notify",
    },
    config = function()
      require("noice").setup({
        presets = {
          lsp_doc_border = true
        }
      })
    end,
  },

  -- Autopairs
  {
    "windwp/nvim-autopairs",
    config = function()
      require("nvim-autopairs").setup()
    end,
  },

  -- Surround
  {
    "kylechui/nvim-surround",
    config = function()
      require("nvim-surround").setup({
        keymaps = {
          normal = "s",
          normal_cur = "ss",
          normal_line = "S",
          normal_cur_line = "SS",
          visual = "s",
          visual_line = "S",
          change = "cs",
          change_line = "cS",
          delete = "ds",
          delete_line = "dS",
        },
      })
    end,
  },

  -- Treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    dependencies = {
      "nvim-treesitter/nvim-treesitter-textobjects",
    },
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          "lua", "nix", "rust", "typescript", "javascript", "html", "css",
          "json", "markdown", "bash", "c", "kotlin", "go", "sql"
        },
        highlight = { enable = true },
        indent = { enable = true },
        textobjects = {
          select = {
            enable = true,
            lookahead = true,
          },
          swap = {
            enable = true,
            swap_next = {
              ["ma"] = "@parameter.inner",
            },
            swap_previous = {
              ["mA"] = "@parameter.outer",
            },
          },
        },
      })
    end,
  },

  -- Which-key
  {
    "folke/which-key.nvim",
    config = function()
      require("which-key").setup()
    end,
  },

  -- Icons
  "nvim-tree/nvim-web-devicons",

  -- Snippets
  {
    "L3MON4D3/LuaSnip",
    build = "make install_jsregexp",
  },
})
