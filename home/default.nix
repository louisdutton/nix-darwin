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
  programs.waybar.enable = true;
  programs.wofi = {
    enable = true;
  };
  services.hyprpaper.enable = true;
}
