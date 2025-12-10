_: {
  stylix.targets.neovim = {
    enable = true;
    transparentBackground = {
      main = true;
      numberLine = true;
      signColumn = true;
    };
  };

  programs.neovim = {
    enable = true;
    defaultEditor = false;
    viAlias = true;
    vimAlias = true;
  };

  xdg.configFile.nvim = {
    source = ./nvim;
    recursive = true;
  };
}
