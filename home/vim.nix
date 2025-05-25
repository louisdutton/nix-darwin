{self, ...}: {
  stylix.targets.nvf.enable = false;

  programs.nvf = {
    enable = true;
    defaultEditor = true;
    enableManpages = true;

    # https://notashelf.github.io/nvf/options.html
    settings.vim = {
      viAlias = true;
      vimAlias = true;

      options = {
        shiftwidth = 4;
        wrap = false; # don't wrap lines
        clipboard = "unnamedplus"; # system clipboard
        scrolloff = 10; # vertical scroll padding
        breakindent = true;
        shortmess = "I"; # remove welcome message
        undofile = true; # persistent history
        ignorecase = true; # case-insensitive search
        smartcase = true; # introduce case-sensitivity when a capital is typed
        updatetime = 250; # 4000ms -> 250ms
      };
      # debugMode = {
      #   enable = false;
      #   level = 16;
      #   logFile = "/tmp/nvim.log";
      # };

      binds.whichKey.enable = true;
      keymaps = let
        mkMap = mode: key: action: desc: {
          inherit key action desc mode;
          silent = true;
        };
        nmap = mkMap "n";
        xmap = mkMap ["n" "x"];
      in [
        (xmap ";" ":" "Command")
        (xmap "H" "^" "Line start")
        (xmap "L" "$" "Line end")
        (xmap "K" "gg" "Buffer start")
        (xmap "J" "G" "Buffer end")

        (nmap "U" "<C-r>" "Redo")
        (nmap "<leader>f" ":FzfLua git_files<cr>" "Find files")
        (nmap "<leader>/" ":FzfLua live_grep_native<cr>" "Find text")
        (nmap "gr" ":FzfLua lsp_references<cr>" "Find references")
        (nmap "gd" ":FzfLua lsp_definitions<cr>" "Find definitions")
        (nmap "gD" ":FzfLua lsp_declarations<cr>" "Find declarations")
        (nmap "gt" ":FzfLua lsp_typedefs<cr>" "Find type definitions")
        (nmap "gI" ":FzfLua lsp_implementations<cr>" "Find implementations")
      ];

      lsp = {
        enable = true;
        formatOnSave = true;
        lspkind.enable = true;
        # otter-nvim.enable = isMaximal;

        mappings = {
          hover = "<leader>k";
          openDiagnosticFloat = "<leader>d";

          codeAction = "<leader>a";
          renameSymbol = "<leader>r";
        };

        servers = {
          biome = {
            filetypes = ["typescript" "typescriptreact" "css" "html" "json"];
            cmd = ["biome" "lsp-proxy"];
          };

          # tailwindcss = {
          #   settings.tailwindCSS.classFunctions = ["cva" "cx"];
          # };
        };
      };

      # debugger = {
      #   nvim-dap = {
      #     enable = true;
      #     ui.enable = true;
      #   };
      # };

      languages = {
        enableFormat = true;
        enableTreesitter = true;
        enableExtraDiagnostics = true;

        # system
        markdown.enable = true;
        bash.enable = true;
        nix = {
          enable = true;
          lsp.server = "nixd";
          lsp.options = let
            flake = ''(builtins.getFlake "${self}")'';
            host = "nixos";
          in {
            nixos.expr = "${flake}.nixosConfigurations.${host}.options";
            # nix-darwin.expr = "${flake}.darwinConfigurations.${host}.options";
            home-manager.expr = "${flake}.homeConfigurations.${host}.options";
            # btcpay.expr = "(builtins.getFlake (builtins.toString ./.)).nixosConfigurations.btcpay.options";
          };
        };

        rust = {
          enable = true;
          lsp.opts = ''
            ['rust-analyzer'] = {
                cargo = { allFeature = true },
                checkOnSave = true,
                procMacro = { enable = true },
                files = {
                    excludeDirs = {
                        ".direnv"
                    },
                },
            },
          '';
        };

        kotlin.enable = true;

        # web
        css = {
          enable = true;
          format.type = "biome";
        };
        ts = {
          enable = true;
          format.type = "biome";
        };
        html.enable = true;
        tailwind.enable = true;
        go.enable = true;
        sql = {
          enable = true;
          dialect = "postgres";
        };
      };

      visuals = {
        nvim-web-devicons.enable = true;
        # highlight-undo.enable = true;
      };

      autocomplete.blink-cmp = {
        enable = true;
      };

      autopairs.nvim-autopairs.enable = true;
      snippets.luasnip.enable = true;
      ui.noice.enable = true;

      fzf-lua = {
        enable = true;
        profile = "fzf-native";
      };

      git = {
        enable = true;
        gitsigns.enable = true;
        # gitsigns.codeActions.enable = false;
      };

      treesitter.textobjects = {
        enable = true;
        setupOpts = {
          select = {
            enable = true;
            lookahead = true;
          };

          swap = {
            enable = true;
            swap_next = {
              ma = "@parameter.inner";
            };
            swap_previous = {
              mA = "@parameter.outer";
            };
          };
        };
      };

      utility = {
        oil-nvim.enable = true;
        surround = {
          enable = true;
          setupOpts.keymaps = {
            normal = "s";
            normal_cur = "ss";
            normal_line = "S";
            normal_cur_line = "SS";
            visual = "s";
            visual_line = "S";
            change = "cs";
            change_line = "cS";
            delete = "ds";
            delete_line = "dS";
          };
        };
      };

      terminal = {
        toggleterm = {
          enable = true;
          lazygit.enable = true;
          lazygit.mappings.open = "<leader>g";
        };
      };

      theme = {
        enable = true;
        name = "catppuccin";
        transparent = true;
        style = "frappe";
      };
    };
  };
}
