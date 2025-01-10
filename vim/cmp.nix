{
  programs.nixvim.plugins = {
    blink-cmp = {
      enable = true;
      settings.signature.enabled = true;
      settings.completion.list.selection = "manual";
      settings.sources.cmdline = [ ];
      settings.keymap = {
        preset = "enter";
        cmdline = {
          preset = "default";
        };
      };
    };
  };
}
