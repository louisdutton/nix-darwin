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
          "bluetooth"
          "network"
          "clock"
          "battery"
        ];
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
