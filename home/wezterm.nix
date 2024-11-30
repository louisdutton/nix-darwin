{ pkgs, lib, ... }:
{
  programs.wezterm = {
    enable = true;
    extraConfig = # lua
      ''
        local wezterm = require 'wezterm'
        local config = wezterm.config_builder()
        local action = wezterm.action

        -- shell
        config.default_prog = { '${lib.getExe pkgs.nushell}' }

        -- window
        config.window_close_confirmation = "NeverPrompt"
        config.window_decorations = 'RESIZE'
        config.front_end = 'WebGpu'
        config.enable_tab_bar = false

        -- fonts
        config.line_height = 0.8
        config.freetype_load_flags = 'NO_HINTING'

        -- cursor
        config.cursor_blink_rate = 0

        -- keymaps
        config.send_composed_key_when_left_alt_is_pressed = true
        config.send_composed_key_when_right_alt_is_pressed = false
        config.keys = {
        	{ mods = "CMD", key = "Backspace", action = action.SendKey({ mods = "CTRL", key = "u" }) },
        }

        -- misc
        config.audible_bell = 'Disabled'

        return config		
      '';
  };
}
