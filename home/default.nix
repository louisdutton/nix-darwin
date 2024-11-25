{ pkgs, ... }:
{
  imports = [
    ./zsh.nix
    ./starship.nix
    ./git.nix
    ./wezterm.nix
    ./email.nix
    ./firefox
    # ./desktop.nix
  ];

  home.stateVersion = "24.05";
  home.packages = with pkgs; [
    devbox
    gcalcli
    sd
    xh
    jq
    openpomodoro-cli
  ];

  home.sessionVariables = {
    MANPAGER = "nvim +Man!";
    EDITOR = "nvim";
    VISUAL = "nvim";
    ZSH_SYSTEM_CLIPBOARD_USE_WL_CLIPBOARD = "true";
  };
}
