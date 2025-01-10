{
  programs.nixvim.plugins = {
    blink-cmp = {
      enable = true;
      settings.signature.enabled = true;
      settings.sources.cmdline = null;
      settings.keymap = {
        preset = "enter";
        cmdline = {
          preset = "default";
        };
        "<Tab>" = [
          "select_next"
          "snippet_forward"
          "fallback"
        ];
        "<S-Tab>" = [
          "select_prev"
          "snippet_backward"
          "fallback"
        ];
      };
    };
  };
}
