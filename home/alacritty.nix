let
  colors = {
    primary = {
      background = "#1e1e2e";
      foreground = "#cdd6f4";
      dim_foreground = "#7f849c";
      bright_foreground = "#cdd6f4";
    };

    cursor = {
      text = "#1e1e2e";
      cursor = "#f5e0dc";
    };

    vi_mode_cursor = {
      text = "#1e1e2e";
      cursor = "#b4befe";
    };

    search.matches = {
      foreground = "#1e1e2e";
      background = "#a6adc8";
    };

    search.focused_match = {
      foreground = "#1e1e2e";
      background = "#a6e3a1";
    };

    footer_bar = {
      foreground = "#1e1e2e";
      background = "#a6adc8";
    };

    hints.start = {
      foreground = "#1e1e2e";
      background = "#f9e2af";
    };

    hints.end = {
      foreground = "#1e1e2e";
      background = "#a6adc8";
    };

    selection = {
      text = "#1e1e2e";
      background = "#f5e0dc";
    };

    normal = {
      black = "#45475a";
      red = "#f38ba8";
      green = "#a6e3a1";
      yellow = "#f9e2af";
      blue = "#89b4fa";
      magenta = "#f5c2e7";
      cyan = "#94e2d5";
      white = "#bac2de";
    };

    bright = {
      black = "#585b70";
      red = "#f38ba8";
      green = "#a6e3a1";
      yellow = "#f9e2af";
      blue = "#89b4fa";
      magenta = "#f5c2e7";
      cyan = "#94e2d5";
      white = "#a6adc8";
    };

    dim = {
      black = "#45475a";
      red = "#f38ba8";
      green = "#a6e3a1";
      yellow = "#f9e2af";
      blue = "#89b4fa";
      magenta = "#f5c2e7";
      cyan = "#94e2d5";
      white = "#bac2de";
    };

    indexed_colors = [
      {
        index = 16;
        color = "#fab387";
      }
      {
        index = 17;
        color = "#f5e0dc";
      }
    ];
  };
in
{
  programs.alacritty = {
    enable = true;
    settings = {
      inherit colors;
      cursor.style = "Beam";

      window = {
        decorations = "Buttonless";
        startup_mode = "Windowed";
        resize_increments = true;
        opacity = 1.0;
        blur = false;
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
        normal.family = "JetBrainsMono Nerd Font";
        size = 11;
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
