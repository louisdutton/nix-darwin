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
        nmap = key: action: desc: {
          inherit key action desc;
          mode = "n";
          silent = true;
        };
      in [
        (nmap ";" ":" "Command")
        (nmap "U" "<C-r>" "Redo")
        (nmap "<leader>f" ":FzfLua git_files<cr>" "Find files")
        (nmap "<leader>/" ":FzfLua live_grep_native<cr>" "Find text")
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

          goToDeclaration = "gD";
          goToDefinition = "gd";
          goToType = "gt";
          listImplementations = "gI";
          listReferences = "gr";
        };

        # servers = {
        #   biome = {
        #     filetypes = ["typescript" "typescriptreact" "css" "html" "json"];
        #     cmd = ["biome" "lsp-proxy"];
        #   };
        # };
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
            # nixpkgs.expr = "import <nixpkgs> {}";
            nixos.expr = "${flake}.nixosConfigurations.${host}.options";
            nix-darwin.expr = "${flake}.darwinConfigurations.${host}.options";
            home-manager.expr = "${flake}.homeConfigurations.${host}.options";
          };
        };

        # rust = {
        #   enable = isMaximal;
        #   crates.enable = isMaximal;
        # };

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
        sql.enable = true;
      };

      visuals = {
        nvim-web-devicons.enable = true;
        # highlight-undo.enable = true;
      };

      autocomplete.blink-cmp.enable = true;
      autopairs.nvim-autopairs.enable = true;
      notes.todo-comments.enable = true;
      snippets.luasnip.enable = true;
      assistant.codecompanion-nvim.enable = false;
      fzf-lua.enable = true;
      ui.noice.enable = true;

      git = {
        enable = true;
        gitsigns.enable = true;
        # gitsigns.codeActions.enable = false;
      };

      utility = {
        oil-nvim.enable = true;
        surround = {
          enable = true;
          setupOpts.keymaps = {
            normal = "s";
            normal_curr_line = "ss";
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
