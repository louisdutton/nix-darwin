{
  wayland.windowManager.hyprland = {
    enable = true;
    settings =
      let
        term = "kitty";
        menu = "wofi --show drun -a";
        wallpaper = "hyprpaper";
        bar = "waybar";
        mod = "ALT";
      in
      {
        exec-once = [
          term
          wallpaper
          bar
          # "nm-applet --indicator"
        ];

        input = {
          kb_layout = "gb";
          repeat_delay = 200;
          touchpad.natural_scroll = true;
        };

        decoration = {
          rounding = 10;
          drop_shadow = false;
          blur = {
            enabled = true;
            size = 8;
            passes = 2;
            vibrancy = 0.1696;
          };
        };

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
      };
  };

  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        modules-left = [
          "hyprland/workspaces"
        ];
        modules-center = [
          "hyprland/window"
        ];
        modules-right = [
          "pulseaudio"
          "network"
          "battery"
          "clock"
          "tray"
        ];
        tray = {
          spacing = 10;
        };
        clock = {
          format = '' {:L%H:%M}'';
          format-alt = "{:%Y-%m-%d}";
        };
        pulseaudio = {
          format = "{icon} {volume}% {format_source}";
          format-bluetooth = "{volume}% {icon} {format_source}";
          format-bluetooth-muted = " {icon} {format_source}";
          format-muted = " {format_source}";
          format-source = " {volume}%";
          format-source-muted = "";
          format-icons = {
            headphone = "";
            hands-free = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default = [
              ""
              ""
              ""
            ];
          };
          on-click = "sleep 0.1 && pavucontrol";
        };
        battery = {
          states = {
            warning = 30;
            critical = 15;
          };
          format = "{icon} {capacity}%";
          format-charging = "󰂄 {capacity}%";
          format-plugged = "󱘖 {capacity}%";
          format-icons = [
            "󰁺"
            "󰁻"
            "󰁼"
            "󰁽"
            "󰁾"
            "󰁿"
            "󰂀"
            "󰂁"
            "󰂂"
            "󰁹"
          ];
          on-click = "";
          tooltip = false;
        };
        network = {
          format-icons = [
            "󰤯"
            "󰤟"
            "󰤢"
            "󰤥"
            "󰤨"
          ];
          format-ethernet = " {bandwidthDownOctets}";
          format-wifi = "{icon} {signalStrength}%";
          format-disconnected = "󰤮";
          tooltip = false;
        };
        "hyprland/workspaces" = {
          disable-scroll = true;
          all-outputs = true;
        };
      };
    };

  };
  programs.wofi = {
    enable = true;
  };
  services.hyprpaper = {
    enable = true;
    settings = {
      splash = true;
      ipc = false;
    };
  };
}
