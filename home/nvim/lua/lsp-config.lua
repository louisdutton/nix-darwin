-- LSP configuration
local lspconfig = require("lspconfig")

-- Setup completion capabilities
local capabilities = require("blink.cmp").get_lsp_capabilities()

-- LSP performance optimizations
vim.lsp.set_log_level("WARN")

-- Format on save
vim.api.nvim_create_autocmd("BufWritePre", {
  callback = function()
    vim.lsp.buf.format({ async = false })
  end,
})

-- LSP servers configuration
local servers = {
  -- Nix
  nixd = {
    cmd = { "nixd" },
    settings = {
      nixd = {
        formatting = {
          command = { "alejandra" },
        },
        options = {
          nixos = {
            expr = "(builtins.getFlake \"/home/louis/.config/nixos\").nixosConfigurations.nixos.options",
          },
          ["home-manager"] = {
            expr =
            "(builtins.getFlake \"/home/louis/.config/nixos\").nixosConfigurations.nixos.options.home-manager.users.type.getSubOptions []",
          },
        },
      },
    },
  },

  -- Rust
  rust_analyzer = {
    settings = {
      ["rust-analyzer"] = {
        cargo = { allFeatures = true },
        checkOnSave = true,
        procMacro = { enable = true },
        files = {
          excludeDirs = { ".direnv" },
        },
      },
    },
  },

  -- TypeScript/JavaScript
  tsserver = {
    filetypes = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
    cmd = { "typescript-language-server", "--stdio" },
  },

  biome = {
    filetypes = { "typescript", "typescriptreact", "javascript", "javascriptreact", "css", "html", "json" },
    cmd = { "biome", "lsp-proxy" },
  },

  -- JSON
  jsonls = {
    filetypes = { "json", "jsonc" },
    cmd = { "vscode-json-language-server", "--stdio" },
  },

  -- HTML
  html = {},

  -- CSS
  cssls = {},

  -- Tailwind
  tailwindcss = {},

  -- Go
  gopls = {},

  -- Clang
  clangd = {},

  -- Kotlin
  kotlin_language_server = {},

  -- Bash
  bashls = {},

  -- SQL
  sqlls = {},

  -- Lua
  lua_ls = {
    settings = {
      Lua = {
        diagnostics = {
          globals = { "vim" },
        },
        workspace = {
          library = vim.api.nvim_get_runtime_file("", true),
          checkThirdParty = false,
          maxPreload = 100000,
          preloadFileSize = 10000,
        },
        telemetry = {
          enable = false,
        }
      },
    },
  },

  -- WGSL
  wgsl_analyzer = {
    filetypes = { "wgsl" },
    cmd = { "wgsl-analyzer" },
  },
}

-- Setup each server
for server, config in pairs(servers) do
  config.capabilities = capabilities
  lspconfig[server].setup(config)
end
