{ pkgs, ... }:
{
  imports = [
    ./keymaps.nix
    ./lsp.nix
    ./format.nix
    ./options.nix
    ./autocmd.nix
    ./completion.nix
  ];

  programs.nixvim = {
    enable = true;
    viAlias = true;
    vimAlias = true;

    colorschemes.everforest = {
      enable = true;
      settings = {
        transparent_background = 2;
      };
    };

    extraPlugins = with pkgs.vimPlugins; [ nvim-surround ];
    extraConfigLua = # lua
      ''
        require('nvim-surround').setup({
        	keymaps = {
        		insert = "<C-g>s",
        		insert_line = "<C-g>S",
        		normal = "s",
        		normal_cur = "ss",
        		normal_line = "S",
        		normal_cur_line = "SS",
        		visual = "s",
        		visual_line = "S",
        		delete = "ds",
        		change = "cs",
        		change_line = "cS",
        	}
        })
      '';

    plugins = {
      lualine.enable = true;
      treesitter.enable = true;
      treesitter-textobjects.enable = true;
      oil.enable = true;

      noice = {
        enable = true;
        presets = {
          lsp_doc_border = true;
        };
      };

      mini = {
        enable = true;
        modules = {
          pairs = { };
          ai = { };
        };
      };

      gitsigns = {
        enable = true;
        settings = {
          signcolumn = true;
          numhl = true;
          current_line_blame = false;
          current_line_blame_opts = {
            delay = 0;
          };
          watch_gitdir.follow_files = true;
          signs = {
            add.text = "┃";
            change.text = "┃";
            changedelete.text = "┃";
            delete.text = "┃";
            topdelete.text = "┃";
            untracked.text = "┆";
          };
        };
      };

      lazygit = {
        enable = true;
        gitPackage = null;
        lazygitPackage = null;
      };

      telescope = {
        enable = true;
        keymaps = {
          "<leader>t" = "builtin";
          "<leader>f" = "find_files";
          "<leader>/" = "live_grep";
          "?" = "current_buffer_fuzzy_find";
        };
      };
    };
  };
}
