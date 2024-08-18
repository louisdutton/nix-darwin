{ ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autocd = true;
    dotDir = "~/.config/zsh";

    sessionVariables = {
      MANPAGER="nvim +Man! -";
    };
    history = {
      expireDuplicatesFirst = true;
      ignoreDups = true;
      ignoreSpace = true;
      save = 20000;
      size = 20000;
      share = true;
    };

    shellAliases = {
      rebuild = "darwin-rebuild switch --flake ~/.config/nix-darwin/";
      c = "clear";
      e = "$EDITOR";
      g = "lazygit";
      top = "btop";
    };
  };
}
