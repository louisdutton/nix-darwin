let
  bind = key: action: {
    inherit key action;
    options.silent = true;
  };
  nmap = key: action: bind key action // { mode = "n"; };
  omap = key: action: bind key action // { mode = "o"; };
in
{
  programs.nixvim = {
    globals.mapleader = " ";

    keymaps = [
      # quick commands
      (bind ";" ":")

      # navigation
      (bind "m" "h")
      (bind "n" "j")
      (bind "e" "k")
      (bind "i" "l")
      (bind "M" "^")
      (bind "I" "$")
      (bind "E" "gg")
      (bind "N" "G")

      # fix o-pending bindings
      (omap "i" "i")

      # colemek insert
      (bind "s" "i")
      (bind "S" "I")

      # colemek next/prev
      (bind "h" "n")
      (bind "H" "N")

      # redo
      (nmap "U" "<c-r>")

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
        "<leader>i" = "hover";
        "<leader>r" = "rename";
      };
    };
  };
}
