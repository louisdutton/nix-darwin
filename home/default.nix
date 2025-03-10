{ pkgs, ... }:
{
  imports = [
    ./nushell.nix
    ./starship.nix
    ./git.nix
    ./wezterm.nix
    ./browser
    ./helix.nix
  ];

  home.stateVersion = "24.05";
  home.packages = with pkgs; [
    devbox
    sd
    fd
  ];

  # allow helix to use its theme
  stylix.targets.helix.enable = false;
}
