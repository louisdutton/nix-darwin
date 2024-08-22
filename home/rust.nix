{
  config,
  lib,
  pkgs,
  ...
}:
let
  mod = "rust";
  cfg = config.${mod};
in
{
  options.${mod} = {
    enable = lib.mkEnableOption "Rust module for home-manager";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      cargo
      rustc
      gcc
      rustfmt
    ];
  };
}
