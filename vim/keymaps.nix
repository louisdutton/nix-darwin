let
  bind = key: action: {
    inherit key action;
    options.silent = true;
  };
  nmap = key: action: bind key action // { mode = "n"; };
in
{ keymap, pkgs, ... }:
{
  programs.nixvim = {
    globals.mapleader = " ";

    keymaps = with keymap; [
      # quick commands
      (bind ";" ":")

      # navigation
      (bind farleft "^")
      (bind farright "$")
      (bind farup "gg")
      (bind fardown "G")

      # redo
      (nmap undo "u")
      (nmap redo "<c-r>")

      # git
      (nmap "<leader>g" ":LazyGit<cr>")
      (nmap "<leader>B" ":Gitsigns toggle_current_line_blame<cr>")
      (nmap "<leader>H" ":Gitsigns preview_hunk<cr>")

      # oil
      (nmap "-" ":Oil<cr>")

      # dap
      (nmap "<leader>c" ":DapContinue<cr>")
      (nmap "<leader>i" ":DapStepInto<cr>")
      (nmap "<leader>o" ":DapStepOver<cr>")
      (nmap "<leader>O" ":DapStepOut<cr>")
      (nmap "<leader>b" ":DapToggleBreakpoint<cr>")
      (nmap "<leader>b" ":DapToggleBreakpoint<cr>")
      (nmap "<leader>K" ":lua require('dapui').eval()<cr>")
      (nmap "<leader>D" ":lua require('dapui').toggle()<cr>")
    ];

    plugins.fzf-lua = {
      enable = true;
      fzfPackage = pkgs.fzf;
      settings = {
        winopts = {
          preview.default = "bat_native";
          backdrop = 100;
        };
        # fzf_opts."--ansi" = false;
        files = {
          git_icons = false;
          file_icons = false;
        };
      };
      keymaps =
        let
          jump = action: {
            inherit action;
            settings = {
              sync = true;
              jump_to_single_result = true;
            };
          };
          noPreview = action: {
            inherit action;
            settings = {
              winopts.preview.hidden = "hidden";
            };
          };
        in
        {
          # unique
          "<leader>F" = "resume";

          # grep
          "<leader>/" = "live_grep_native";

          # buffers and files
          "<leader>ff" = "files";
          "<leader>fo" = "oldfiles";
          "<leader>fb" = "buffers";
          "<leader>fq" = "quickfix";

          # git
          "<leader>fgf" = "git_files";
          "<leader>fgb" = "git_branches";
          "<leader>fgh" = "git_bcommits";

          # lsp
          "gd" = jump "lsp_definitions";
          "gD" = jump "lsp_declarations";
          "gr" = jump "lsp_references";
          "gt" = jump "lsp_typedefs";
          "gi" = jump "lsp_implementations";
          "<leader>a" = noPreview "lsp_code_actions";
          "<leader>fs" = "lsp_live_workspace_symbols";
          "<leader>fd" = "lsp_workspace_diagnostics";

          # misc
          "<leader>fh" = "helptags";
          "<leader>fm" = "manpages";
          "<leader>fc" = "commands";
          "<leader>fk" = "keymaps";
        };
    };

    plugins.lsp.keymaps = {
      silent = true;
      diagnostic = {
        "[d" = "goto_prev";
        "]d" = "goto_next";
      };

      lspBuf = {
        "<leader>k" = "hover";
        "<leader>r" = "rename";
      };
    };
  };
}
