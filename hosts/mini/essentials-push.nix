{
  config,
  lib,
  ...
}: let
  identities = import ./essentials-identities.nix;
  identityFile = builtins.toFile "essentials-device-identities.json" (
    builtins.toJSON {
      devices = lib.mapAttrs (
        _: device: {
          inherit (device) user groups;
        }
      ) identities.devices;
    }
  );
  interface = "wg0";
  listenAddress = "10.70.0.1";
  port = 8090;
  distributorPort = 8092;
in {
  imports = [../../services/essentials-push-gateway/nixos-module.nix];

  # These SOPS paths retain their original names so existing encrypted secrets
  # and provisioned devices continue working during the service split.
  sops.secrets."essentials-sync/auth-tokens" = {
    owner = "essentials-push";
    group = "essentials-push";
    mode = "0400";
    restartUnits = ["essentials-push.service"];
  };
  sops.secrets."essentials-sync/vapid-public-key" = {
    owner = "essentials-push";
    group = "essentials-push";
    mode = "0400";
    restartUnits = ["essentials-push.service"];
  };
  sops.secrets."essentials-sync/vapid-private-key" = {
    owner = "essentials-push";
    group = "essentials-push";
    mode = "0400";
    restartUnits = ["essentials-push.service"];
  };
  sops.secrets."essentials-sync/invalidation-token" = {
    owner = "essentials-push";
    group = "essentials-push";
    mode = "0440";
    restartUnits = ["essentials-push.service" "radicale.service"];
  };

  services.essentialsPushGateway = {
    enable = true;
    inherit listenAddress port identityFile;
    tokenFile = config.sops.secrets."essentials-sync/auth-tokens".path;
    pushEndpointBase = "http://${listenAddress}:${toString distributorPort}";
    vapidPublicKeyFile = config.sops.secrets."essentials-sync/vapid-public-key".path;
    vapidPrivateKeyFile = config.sops.secrets."essentials-sync/vapid-private-key".path;
    vapidSubject = "mailto:louis@xgx.ai";
    invalidationTokenFile = config.sops.secrets."essentials-sync/invalidation-token".path;
  };

  services.ntfy-sh = {
    enable = true;
    settings = {
      base-url = "http://${listenAddress}:${toString distributorPort}";
      listen-http = "${listenAddress}:${toString distributorPort}";
      cache-file = "/var/lib/ntfy-sh/cache.db";
      cache-duration = "24h";
      enable-login = false;
      enable-signup = false;
    };
  };

  systemd.services.essentials-push = {
    after = ["wireguard-${interface}.service"];
    requires = ["wireguard-${interface}.service"];
  };

  networking.firewall.interfaces.${interface}.allowedTCPPorts = [port distributorPort];
}
