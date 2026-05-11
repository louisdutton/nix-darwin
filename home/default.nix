{
  pkgs,
  lib,
  inputs,
  config,
  ...
}: {
  imports = [
    ./shell.nix
    ./prompt.nix
    ./git.nix
  ];

  # self-management
  home.stateVersion = "25.05";
  programs.home-manager.enable = true;
  xdg.enable = true;
  gtk.gtk4.theme = null;

  # required for standalone
  home.username = lib.mkDefault "louis";
  home.homeDirectory = lib.mkDefault /Users/louis;

  home.packages = with pkgs; [
    opencode
    glow
  ];

}
