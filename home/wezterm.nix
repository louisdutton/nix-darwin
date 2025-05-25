{...}: {
  programs.wezterm = {
    enable = true;
    extraConfig =
      # lua
      ''
        local wezterm = require 'wezterm'
        local config = wezterm.config_builder()
        local action = wezterm.action

        return {
          -- window
          window_close_confirmation = "NeverPrompt",
          -- window_background_opacity = 0.9,
          -- macos_window_background_blur = 60,
          window_decorations = 'RESIZE',
          front_end = 'WebGpu',
          enable_tab_bar = false,

          -- fonts
          line_height = 0.8,
          freetype_load_flags = 'NO_HINTING',

          -- cursor
          cursor_blink_rate = 0,

          -- keymaps
          send_composed_key_when_left_alt_is_pressed = true,
          send_composed_key_when_right_alt_is_pressed = false,
          keys = {
          	{ mods = "CMD", key = "Backspace", action = action.SendKey({ mods = "CTRL", key = "u" }) },
          },

          -- misc
          audible_bell = 'Disabled',
        }
      '';
  };
}
