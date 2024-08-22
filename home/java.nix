{
  config,
  lib,
  pkgs,
  ...
}:
let
  mod = "java";
  cfg = config.${mod};
in
{
  options.${mod} = {
    enable = lib.mkEnableOption "Java module for home-manager";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [ maven ];

    programs.java = {
      enable = true;
      package = pkgs.openjdk8;
    };
  };
}
