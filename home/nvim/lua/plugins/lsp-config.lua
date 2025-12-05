return {
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile", },
    config = function()
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
                  expr =
                  "(builtins.getFlake \"/Users/louis/projects/evergive/evergive\").nixosConfigurations.eg-api-00.options",
                },
                -- ["home-manager"] = {
                --   expr = "(builtins.getFlake \"/Users/louis/.config/nix-darwin\").homeConfigurations.nixos.options",
                -- },
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
        ts_ls = {
          filetypes = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
          cmd = { "typescript-language-server", "--stdio" },
          on_attach = function(client, bufnr)
            client.server_capabilities.documentFormattingProvider = false
            client.server_capabilities.documentRangeFormattingProvider = false
          end,
        },

        denols = {},

        biome = {
          filetypes = { "typescript", "typescriptreact", "javascript", "javascriptreact", "css", "html", "json", "jsonc", "grit" },
          cmd = { "biome", "lsp-proxy" },
        },

        -- JSON
        jsonls = {
          filetypes = { "json", "jsonc" },
          cmd = { "vscode-json-language-server", "--stdio" },
          on_attach = function(client, bufnr)
            client.server_capabilities.documentFormattingProvider = false
            client.server_capabilities.documentRangeFormattingProvider = false
          end,
        },

        -- HTML
        html = {},

        -- CSS
        cssls = {},

        -- Tailwind
        tailwindcss = {},

        -- Clang
        clangd = {},

        -- Bash
        bashls = {},

        -- SQL
        sqlls = {},

        -- Odin
        ols = {},

        -- QML
        qmlls = {
          cmd = { "qmlls", "-E" }
        },

        -- Android
        dartls = {},

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
      }

      -- Setup each server
      for server, config in pairs(servers) do
        config.capabilities = capabilities
        lspconfig[server].setup(config)
      end
    end,
  },
}
