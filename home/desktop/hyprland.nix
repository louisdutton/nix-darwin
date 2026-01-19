{
  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = false; # UWSM handles session management
    settings = let
      term = "ghostty";
      menu = "wofi --show drun -a";
      wallpaper = "hyprpaper";
      bar = "waybar";
      mod = "ALT";
    in {
      exec-once = [
        term
        wallpaper
        bar
        # "nm-applet --indicator"
      ];

      general = {
        border_size = 2;
        gaps_in = 5;
        gaps_out = 10;
      };

      input = {
        kb_layout = "gb";
        repeat_delay = 200;
        touchpad.natural_scroll = true;
      };

      decoration = {
        rounding = 10;
        shadow.enabled = false;
        blur.enabled = false;
      };

      # don't render whilst nothing changes on screen
      misc.vfr = true;

      bind = [
        # Example binds, see https://wiki.hyprland.org/Configuring/Binds/ for more
        "${mod}, Q, killactive"
        "${mod}, M, exit"
        "${mod}, N, exec, ${term}"
        "${mod}, V, togglefloating"
        "${mod}, SPACE, exec, ${menu}"
        "${mod}, F, fullscreen"

        # Move focus with mainMod + hjkl
        "${mod}, H, movefocus, l"
        "${mod}, L, movefocus, r"
        "${mod}, K, movefocus, u"
        "${mod}, J, movefocus, d"

        # Switch workspaces with mainMod + [0-9]
        "${mod}, 1, workspace, 1"
        "${mod}, 2, workspace, 2"
        "${mod}, 3, workspace, 3"
        "${mod}, 4, workspace, 4"
        "${mod}, 5, workspace, 5"
        "${mod}, 6, workspace, 6"
        "${mod}, 7, workspace, 7"
        "${mod}, 8, workspace, 8"
        "${mod}, 9, workspace, 9"
        "${mod}, 0, workspace, 10"

        # Move active window to a workspace with mainMod + SHIFT + [0-9]
        "${mod} SHIFT, 1, movetoworkspace, 1"
        "${mod} SHIFT, 2, movetoworkspace, 2"
        "${mod} SHIFT, 3, movetoworkspace, 3"
        "${mod} SHIFT, 4, movetoworkspace, 4"
        "${mod} SHIFT, 5, movetoworkspace, 5"
        "${mod} SHIFT, 6, movetoworkspace, 6"
        "${mod} SHIFT, 7, movetoworkspace, 7"
        "${mod} SHIFT, 8, movetoworkspace, 8"
        "${mod} SHIFT, 9, movetoworkspace, 9"
        "${mod} SHIFT, 0, movetoworkspace, 10"
      ];
      bindle = [
        ",XF86AudioRaiseVolume, exec, pamixer -i 5"
        ",XF86AudioLowerVolume, exec, pamixer -d 5"
        ",XF86AudioMute, exec, pamixer -t"
        ",XF86MonBrightnessUp, exec, light -A 30"
        ",XF86MonBrightnessDown, exec, light -U 30"
        # ",XF86Search, exec, launchpad"
      ];
      bindl = [
        ",XF86AudioPlay, exec, playerctl play-pause"
        ",XF86AudioNext, exec, playerctl next"
        ",XF86AudioPrev, exec, playerctl previous"
      ];
    };
  };
}
