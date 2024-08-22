let
  bind = key: action: {
    inherit key action;
    options.silent = true;
  };
  nmap = key: action: bind key action // { mode = "n"; };
in
{
  programs.nixvim = {
    globals.mapleader = " ";

    keymaps = [
      # quick commands
      (bind ";" ":")

      # navigation
      (bind "H" "^")
      (bind "L" "$")
      (bind "K" "gg")
      (bind "J" "G")

      # surround
      (nmap "s" "ys")
      (nmap "S" "yS")

      # delete and change
      (nmap "dH" "d^")
      (nmap "dL" "d$")
      (nmap "cH" "c^")
      (nmap "cL" "c$")

      # redo
      (nmap "U" "<c-r>")

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
