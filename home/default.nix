{pkgs, ...}: {
  imports = [
    ./shell.nix
    ./prompt.nix
    ./git.nix
    ./terminal.nix
    ./vim.nix
    ./ssh.nix
    ./dictation.nix
    ./desktop
  ];

  # self-management
  home.stateVersion = "25.05";
  programs.home-manager.enable = true;
  xdg.enable = true;

  home.packages = with pkgs; [
    sd # better sed
    fd # better find
    xh # better curl
    jq # json query

    # web
    ddgr
    w3m
  ];
}
