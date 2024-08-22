{ pkgs, ... }:
{
  imports = [
    ./zsh.nix
    ./git.nix
    ./aws.nix
    ./javascript.nix
    ./rust.nix
    ./go.nix
    ./java.nix
    ./alacritty.nix
  ];

  home.stateVersion = "24.05";
  home.packages = with pkgs; [
    sd
    xh
    jq
  ];

  home.sessionVariables = {
    MANPAGER = "nvim +Man!";
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  # languages
  javascript.enable = true;
  rust.enable = true;
  java.enable = false;
  go.enable = true;
}
