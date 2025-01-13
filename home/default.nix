{ pkgs, ... }: {
  imports = [
    ./nushell.nix
    ./starship.nix
    ./git.nix
    ./wezterm.nix
    ./firefox
    ./helix.nix
  ];

  home.stateVersion = "24.05";
  home.packages = with pkgs; [ devbox sd fd ];
}
