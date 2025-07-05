{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./shell.nix
    ./prompt.nix
    ./git.nix
    ./wezterm.nix
    ./vim.nix
    ./process-compose.nix
    ./ssh.nix
    ./dictation.nix
  ];

  # self-management
  home.stateVersion = "25.05";
  programs.home-manager.enable = true;
  xdg.enable = true;

  # required for standalone
  home.username = lib.mkDefault "louis";
  home.homeDirectory = lib.mkDefault /Users/louis;

  home.packages = with pkgs; [
    devbox # nix abstraction layer
    sd # better sed
    fd # better find
    xh # better curl
    jq # json query

    # agentic tools
    claude-code 
    glow
  ];

  programs.chromium = {
    enable = true;
    package = pkgs.brave;
    extensions = [
      {id = "ghmbeldphafepmbegfdlkpapadhbakde";} # proton pass
      {id = "gfbliohnnapiefjpjlpjnehglfpaknnc";} # surfing keys
    ];
  };
}
