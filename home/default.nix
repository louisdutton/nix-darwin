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

  home.stateVersion = "24.05";
  home.packages = with pkgs; [
    devbox
    sd
    fd
    jq
  ];

  # allow helix to use its theme
  stylix.targets.helix.enable = false;
}
