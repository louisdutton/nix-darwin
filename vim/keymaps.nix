let
  bind = key: action: {
    inherit key action;
    options.silent = true;
  };
  nmap = key: action: bind key action // { mode = "n"; };
in
{ keymap, ... }:
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

      # save and quit
      (nmap "<leader>w" ":w<cr>")
      (nmap "<leader>q" ":q<cr>")

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

    plugins.lsp.keymaps = {
      silent = true;
      diagnostic = {
        "[d" = "goto_prev";
        "]d" = "goto_next";
      };

      lspBuf = {
        gd = "definition";
        gr = "references";
        gi = "implementation";
        gt = "type_definition";
        "<leader>a" = "code_action";
        "<leader>k" = "hover";
        "<leader>r" = "rename";
      };
    };
  };
}
