{
  programs.nixvim.plugins = {
    # enable vscode snippets
    friendly-snippets.enable = true;
    luasnip = {
      enable = true;
      fromVscode = [ { } ];
    };

    blink-cmp = {
      enable = true;
      settings.keymap.preset = "enter";
    };
  };
}
