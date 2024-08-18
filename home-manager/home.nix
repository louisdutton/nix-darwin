{ config, pkgs, ... }:
{
  home.stateVersion = "23.11";
  home.packages = with pkgs; [
    ripgrep
    gh
    glab
    # lsp
    nixd
    nil
    nodePackages_latest.typescript-language-server
    vscode-langservers-extracted
    lemminx
    yaml-language-server
    # javascript
    bun
    nodejs
    yarn
    # rust
    rustc
    cargo
    rustfmt
    rust-analyzer
    # ops
    awscli2
  ];

  programs.home-manager.enable = true; # manage itself

  programs.ripgrep.enable = true;

  programs.fzf.enable = true;
  programs.fzf.enableZshIntegration = true;

  programs.zoxide.enable = true; 
  programs.zoxide.enableZshIntegration = true;
  programs.zoxide.options = [
    "--cmd cd"
  ];

  imports = [
    ./git.nix
    ./zsh.nix
    ./lazygit.nix
    ./starship.nix
    ./neovim.nix
  ];
}
