{
  programs.kitty = {
    enable = true;
    settings = {
      enable_audio_bell = false;
      window_padding_width = 10;
      window_padding_height = 10;
    };
  };
  programs.alacritty = {
    enable = false;
    settings = {
      cursor.style = "Beam";

      window = {
        decorations = "Buttonless";
        startup_mode = "Windowed";
        resize_increments = true;
        padding = {
          x = 12;
          y = 12;
        };
      };

      keyboard.bindings = [
        {
          key = "Back";
          mods = "Command";
          chars = "\\u0015";
        }
      ];

      font = {
        offset = {
          x = 0;
          y = -3;
        };
        glyph_offset = {
          x = 0;
          y = -1;
        };
      };
    };
  };
}
