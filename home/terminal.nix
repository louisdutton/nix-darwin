{pkgs, ...}: {
  programs.ghostty = {
    enable = true;
    package = pkgs.ghostty-bin;
    settings = {
      window-decoration = "none";
      window-padding-x = 10;
      window-padding-y = 10;
      adjust-cell-height = "-20%";

      confirm-close-surface = false;
    };
  };
}
