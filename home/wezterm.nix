{
  programs.wezterm = {
    enable = true;
    enableZshIntegration = true;
    extraConfig = ''
      local wezterm = require 'wezterm'
      local config = wezterm.config_builder()

      -- window
      config.window_decorations = 'RESIZE'
      config.front_end = 'WebGpu'
      config.enable_tab_bar = false

      -- fonts
      config.line_height = 0.8
      config.freetype_load_flags = 'NO_HINTING'

      -- cursor
      config.cursor_blink_rate = 0

      -- misc
      config.audible_bell = 'Disabled'

      return config		
    '';
  };
}
