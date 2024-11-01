let
  bind = key: action: {
    inherit key action;
    options.silent = true;
  };
  nmap = key: action: bind key action // { mode = "n"; };
  omap = key: action: bind key action // { mode = "o"; };
in
{ keymap, ... }:
{
  programs.nixvim = {
    globals.mapleader = " ";

    keymaps = with keymap; [
      # quick commands
      (bind ";" ":")

      # navigation
      (bind left "h")
      (bind down "j")
      (bind up "k")
      (bind right "l")
      (bind farleft "^")
      (bind farright "$")
      (bind farup "gg")
      (bind fardown "G")

      # fix o-pending bindings for colemak
      (omap "i" "i")

      # colemak insert
      (bind insert "i")
      (bind farinsert "I")

      # colemak next/prev
      (bind next "n")
      (bind prev "N")

      # redo
      (nmap undo "u")
      (nmap redo "<c-r>")

      # save and quit
      (nmap "<leader>w" ":w<cr>")
      (nmap "<leader>q" ":q<cr>")

      # git
      (nmap "<leader>g" ":LazyGit<cr>")
      (nmap "<leader>B" ":Gitsigns toggle_current_line_blame<cr>")
      (nmap "<leader>h" ":Gitsigns preview_hunk<cr>")
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
