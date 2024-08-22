{
  programs.alacritty = {
    enable = true;
    settings = {
      cursor.style = "Beam";

      window = {
        startup_mode = "Windowed";
        resize_increments = true;
        opacity = 0.925;
        blur = true;
        padding = {
          x = 12;
          y = 12;
        };
      };

      keyboard.bindings = [
        {
          key = "Back";
          mods = "Command";
          chars = "\u0015";
        }
      ];

      font = {
        normal.family = "JetBrainsMono Nerd Font";
        size = 14.5;
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
