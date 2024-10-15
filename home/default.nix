{ pkgs, ... }:
{
  imports = [
    ./zsh.nix
    ./git.nix
    ./alacritty.nix
  ];

  home.stateVersion = "24.05";
  home.packages = with pkgs; [
    sd
    xh
    jq
  ];

  home.sessionVariables = {
    MANPAGER = "nvim +Man!";
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  # desktop
  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 30;
        output = [
          "eDP-1"
          "HDMI-A-1"
        ];
        modules-left = [
          "hyprland/workspaces"
        ];
        modules-center = [
          "hyprland/window"
        ];
        modules-right = [
          # "pulseaudio"
          # "bluetooth"
          "network"
          "battery"
          "clock"
          "tray"
        ];
        tray = {
          icon-size = 21;
          spacing = 10;
        };
        clock = {
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
          format-alt = "{:%Y-%m-%d}";
        };
        battery = {
          states = {
            # good= 95;
            warning = 30;
            critical = 15;
          };
          format = "{capacity}% {icon}";
          format-full = "{capacity}% {icon}";
          format-charging = "{capacity}% ";
          format-plugged = "{capacity}% ";
          format-alt = "{time} {icon}";
          format-icons = [
            ""
            ""
            ""
            ""
            ""
          ];
        };
        network = {
          # "interface"= "wlp2*"; // (Optional) To force the use of this interface
          format-wifi = "{essid} ({signalStrength}%) ";
          format-ethernet = "{ipaddr}/{cidr} ";
          tooltip-format = "{ifname} via {gwaddr} ";
          format-linked = "{ifname} (No IP) ";
          format-disconnected = "Disconnected ⚠";
          format-alt = "{ifname}: {ipaddr}/{cidr}";
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
