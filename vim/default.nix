{ pkgs, ... }:
{
  imports = [
    ./keymaps.nix
    ./lsp.nix
    ./dap.nix
    ./format.nix
    ./options.nix
    ./autocmd.nix
    ./cmp.nix
  ];

  programs.nixvim = {
    enable = true;
    viAlias = true;
    vimAlias = true;

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
      web-devicons.enable = true;

      # syntax parser
      treesitter-textobjects.enable = true;
      treesitter = {
        enable = true;
        settings.highlight.enable = true;
      };

      # filesystem manager
      oil = {
        enable = true;
        settings = {
          skip_confirm_for_simple_edits = true;
          constrain_cursor = "name";
          view_options.show_hidden = true;
          lsp_file_method.autosave_changes = true;
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
    };
  };
}
