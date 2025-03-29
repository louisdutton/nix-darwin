{ pkgs, lib, ... }:
{
  imports = [
    ./shell.nix
    ./prompt.nix
    ./git.nix
    ./wezterm.nix
    ./helix.nix
    ./process-compose.nix
  ];

  # self-management
  home.stateVersion = "25.05";
  programs.home-manager.enable = true;

  # required for standalone
  home.username = lib.mkDefault "louis";
  home.homeDirectory = lib.mkDefault /Users/louis;

  home.packages = with pkgs; [
    devbox # nix abstraction layer
    sd # better sed
    fd # better find
    xh # better curl
    jq # json query
  ];

  # allow helix to use it's own theme
  stylix.targets.helix.enable = false;

  programs.chromium = {
    enable = true;
    package = pkgs.brave;
    extensions = [
      { id = "ghmbeldphafepmbegfdlkpapadhbakde"; } # proton pass
      { id = "gfbliohnnapiefjpjlpjnehglfpaknnc"; } # surfing keys
    ];
  };
}
