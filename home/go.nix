{
  config,
  lib,
  pkgs,
  ...
}:
let
  mod = "go";
  cfg = config.${mod};
in
{
  options.${mod} = {
    enable = lib.mkEnableOption "Go module for home-manager";
  };

  config = lib.mkIf cfg.enable {
    programs.go = {
      enable = true;
    };
  };
}
