{ pkgs, ... }:
{
  imports = [
    ./nushell.nix
    ./starship.nix
    ./git.nix
    ./wezterm.nix
    ./email.nix
    ./firefox
    ./helix.nix
  ];

  home.stateVersion = "24.05";
  home.packages = with pkgs; [
    devbox
    sd
    fd
    bat # needed for fzf-lua
  ];

  home.sessionVariables = {
    MANPAGER = "nvim +Man!";
    EDITOR = "nvim";
    VISUAL = "nvim";
  };
}
