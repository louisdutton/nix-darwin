{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./shell.nix
    ./prompt.nix
    ./git.nix
    ./terminal.nix
    ./vim.nix
    ./agents.nix
  ];

  # self-management
  home.stateVersion = "25.05";
  programs.home-manager.enable = true;
  xdg.enable = true;

  # required for standalone
  home.username = lib.mkDefault "louis";
  home.homeDirectory = lib.mkDefault /Users/louis;

  home.packages = with pkgs; [
    # agentic tools
    opencode
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
