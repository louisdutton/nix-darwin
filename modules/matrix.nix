{
  config,
  lib,
  ...
}: let
  cfg = config.matrix;
  caddyHostName =
    if cfg.caddyHostName == null
    then cfg.serverName
    else cfg.caddyHostName;
in {
  options.matrix = {
    enable = lib.mkEnableOption "Matrix homeserver";

    serverName = lib.mkOption {
      type = lib.types.nonEmptyStr;
      description = "Matrix server name used in user and room IDs.";
    };

    listenAddresses = lib.mkOption {
      type = lib.types.listOf lib.types.nonEmptyStr;
      default = [
        "127.0.0.1"
        "::1"
      ];
      description = "Addresses Tuwunel listens on.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 6167;
      description = "Local Tuwunel HTTP port.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the Tuwunel port directly in the host firewall.";
    };

    enableCaddy = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Expose Matrix client endpoints through Caddy.";
    };

    caddyHostName = lib.mkOption {
      type = lib.types.nullOr lib.types.nonEmptyStr;
      default = null;
      description = "Caddy virtual host name. Defaults to serverName.";
    };

    allowRegistration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow registration using the configured registration token.";
    };

    registrationTokenSecret = lib.mkOption {
      type = lib.types.nonEmptyStr;
      default = "matrix_registration_token";
      description = "sops secret name containing the registration token.";
    };

    allowFederation = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow federation with other Matrix homeservers.";
    };

    trustedServers = lib.mkOption {
      type = lib.types.listOf lib.types.nonEmptyStr;
      default = ["matrix.org"];
      description = "Trusted key servers used by Tuwunel.";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [cfg.port];

    sops.secrets.${cfg.registrationTokenSecret} = {
      owner = config.services.matrix-tuwunel.user;
      group = config.services.matrix-tuwunel.group;
    };

    services.matrix-tuwunel = {
      enable = true;
      settings.global = {
        server_name = cfg.serverName;
        address = cfg.listenAddresses;
        port = [cfg.port];
        allow_registration = cfg.allowRegistration;
        registration_token_file = config.sops.secrets.${cfg.registrationTokenSecret}.path;
        allow_federation = cfg.allowFederation;
        trusted_servers = cfg.trustedServers;
      };
    };

    services.caddy.virtualHosts = lib.mkIf cfg.enableCaddy {
      ${caddyHostName}.extraConfig = ''
        @matrixClient path /.well-known/matrix/client
        header @matrixClient {
          Access-Control-Allow-Origin "*"
          Content-Type application/json
        }
        respond @matrixClient `{"m.homeserver":{"base_url":"https://${caddyHostName}"}}`

        reverse_proxy /_matrix/* 127.0.0.1:${toString cfg.port}
        reverse_proxy /_tuwunel/* 127.0.0.1:${toString cfg.port}
      '';
    };
  };
}
