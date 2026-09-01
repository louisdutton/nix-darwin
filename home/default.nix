{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./shell.nix
    ./prompt.nix
    ./git.nix
    ./zellij.nix
    # ./mail.nix
    # ./desktop
  ];

  # self-management
  home.stateVersion = "25.05";
  programs.home-manager.enable = true;
  programs.devenv.enable = true;
  xdg.enable = true;

  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/projects/nixos/config/nvim";

  home.packages = with pkgs; [
    sd # better sed
    fd # better find
    xh # better curl
    jq # json query
  ];

  # agent
  programs.codex.enable = true;
}
