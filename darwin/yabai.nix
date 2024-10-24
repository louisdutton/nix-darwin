{ ... }:
{
  services.yabai = {
    enable = true;
    # enableScriptingAddition = true;
    config = {
      layout = "bsp";
      auto_balance = "off";
      window_placement = "second_child";

      top_padding = 16;
      bottom_padding = 16;
      left_padding = 16;
      right_padding = 16;
      window_gap = 16;

      focus_follows_mouse = "autofocus";
      mouse_modifier = "alt";
      mouse_action1 = "move";
      mouser_action2 = "resize";
      mouse_drop_action = "swap";

      window_topmost = "off";
      window_opacity = "off";
      window_shadow = "off";
      split_ratio = 0.5;

      external_bar = "all:45:0";
    };

    extraConfig = ''
      # Notify sketchybar when space changes
      yabai -m signal --add event=window_focused action="sketchybar --trigger window_focus"
      yabai -m signal --add event=window_title_changed action="sketchybar --trigger title_change"

      # Rules for specific apps
      yabai -m rule --add app="^System Settings$" manage=off
      yabai -m rule --add label="Finder" app="^Finder$" title="(Co(py|nnect)|Move|Info|Pref)" manage=off
      yabai -m rule --add label="Safari" app="^Safari$" title="^(General|(Tab|Password|Website|Extension)s|AutoFill|Se(arch|curity)|Privacy|Advance)$" manage=off
      yabai -m rule --add label="System Preferences" app="^System Preferences$" title=".*" manage=off
      yabai -m rule --add label="App Store" app="^App Store$" manage=off
      yabai -m rule --add label="Activity Monitor" app="^Activity Monitor$" manage=off
      yabai -m rule --add label="Calculator" app="^Calculator$" manage=off
      yabai -m rule --add label="Dictionary" app="^Dictionary$" manage=off
      yabai -m rule --add label="Software Update" title="Software Update" manage=off
      yabai -m rule --add label="About This Mac" app="System Information" title="About This Mac" manage=off
    '';
  };
}
