{
  programs.alacritty = {
    enable = true;
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
