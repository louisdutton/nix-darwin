{ pkgs, ... }:
{
  imports = [
    ./shell.nix
    ./prompt.nix
    ./git.nix
    ./wezterm.nix
    ./helix.nix
    ./process-compose.nix
  ];

  home.stateVersion = "25.05";
  home.packages = with pkgs; [
    devbox # nix abstraction layer
    sd # better sed
    fd # better find
    xh # better curl
    jq # json query
  ];

  # allow helix to use it's own theme
  stylix.targets.helix.enable = false;
}
