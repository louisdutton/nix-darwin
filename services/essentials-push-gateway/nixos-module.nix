{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.essentialsPushGateway;
  package = pkgs.buildGoModule {
    pname = "essentials-push-gateway";
    version = "1.0.0";
    src = ./.;
    vendorHash = "sha256-HSgf1POUz1mj+yaYtNem5JxPZM/Rt6EnJkw2DG3LFME=";
  };
  migrateLegacySubscriptions = pkgs.writeShellScript "migrate-essentials-push-subscriptions" ''
    new=${lib.escapeShellArg cfg.dataDir}/subscriptions
    old=/var/lib/essentials-sync/push/subscriptions
    ${pkgs.coreutils}/bin/install -d -m 0700 -o essentials-push -g essentials-push "$new"
    if [[ -d "$old" && -z "$(${pkgs.coreutils}/bin/ls -A "$new")" ]]; then
      ${pkgs.coreutils}/bin/cp -a "$old"/. "$new"/
      ${pkgs.coreutils}/bin/chown -R essentials-push:essentials-push "$new"
    fi
  '';
in {
  options.services.essentialsPushGateway = {
    enable = lib.mkEnableOption "Essentials push-invalidation gateway";
    package = lib.mkOption {
      type = lib.types.package;
      default = package;
      description = "Essentials push gateway package.";
    };
    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address on which the service listens.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8090;
      description = "HTTP port used by the service.";
    };
    tokenFile = lib.mkOption {
      type = lib.types.path;
      description = "Root-readable file containing device-name:token lines.";
    };
    identityFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "JSON registry mapping device names to users and groups.";
    };
    pushEndpointBase = lib.mkOption {
      type = lib.types.str;
      description = "Allowed UnifiedPush endpoint base URL.";
    };
    vapidPublicKeyFile = lib.mkOption {
      type = lib.types.path;
      description = "File containing the VAPID public key.";
    };
    vapidPrivateKeyFile = lib.mkOption {
      type = lib.types.path;
      description = "File containing the VAPID private key.";
    };
    vapidSubject = lib.mkOption {
      type = lib.types.str;
      description = "Web Push subscriber contact URI.";
    };
    invalidationTokenFile = lib.mkOption {
      type = lib.types.path;
      description = "File containing the internal invalidation hook token.";
    };
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/essentials-push";
      description = "Persistent push subscription storage.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.essentials-push = {};
    users.users.essentials-push = {
      isSystemUser = true;
      group = "essentials-push";
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0700 essentials-push essentials-push - -"
    ];

    systemd.services.essentials-push = {
      description = "Essentials push-invalidation gateway";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];
      serviceConfig = {
        User = "essentials-push";
        Group = "essentials-push";
        ExecStartPre = "+${migrateLegacySubscriptions}";
        ExecStart = lib.escapeShellArgs (
          [
            "${cfg.package}/bin/essentials-push-gateway"
            "-listen"
            "${cfg.listenAddress}:${toString cfg.port}"
            "-data"
            cfg.dataDir
            "-token-file"
            cfg.tokenFile
            "-push-endpoint-base"
            cfg.pushEndpointBase
            "-vapid-public-key-file"
            cfg.vapidPublicKeyFile
            "-vapid-private-key-file"
            cfg.vapidPrivateKeyFile
            "-vapid-subject"
            cfg.vapidSubject
            "-invalidation-token-file"
            cfg.invalidationTokenFile
          ]
          ++ lib.optionals (cfg.identityFile != null) [
            "-identity-file"
            cfg.identityFile
          ]
        );
        Restart = "on-failure";
        RestartSec = 3;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [cfg.dataDir];
        RestrictAddressFamilies = ["AF_INET" "AF_INET6"];
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
      };
    };
  };
}
