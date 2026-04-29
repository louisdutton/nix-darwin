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
    };
  };
}
