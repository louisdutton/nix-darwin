{
  config,
  lib,
  pkgs,
  ...
}:
let
  mod = "javascript";
  cfg = config.${mod};
in
{
  options.${mod} = {
    enable = lib.mkEnableOption "JavaScript module for home-manager";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [ nodejs ];
    home.sessionVariables = {
      NODE_EXTRA_CA_CERTS = "/etc/ssl/certs/Cloudflare_CA.pem";
    };

    programs.bun = {
      enable = true;
      settings = {
        telemetry = false;
      };
    };
  };
}
