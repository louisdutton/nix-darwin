{
  pkgs,
  lib,
  ...
}: {
  programs.ghostty = {
    enable = true;
    package = pkgs.ghostty-bin;
    settings = {
      font-size = lib.mkForce "14.666666666666666";
      window-decoration = "none";
      window-padding-x = 10;
      window-padding-y = 10;
      adjust-cell-height = "-20%";

      confirm-close-surface = false;
    };
  };
}
