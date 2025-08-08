{...}: {
  programs.ghostty = {
    enable = true;
    settings = {
      window-padding-x = 10;
      window-padding-y = 10;
      adjust-cell-height = "-20%";
    };
  };
}
