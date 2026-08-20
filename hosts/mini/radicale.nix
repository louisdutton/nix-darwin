{
  config,
  lib,
  pkgs,
  ...
}: let
  identities = import ./essentials-identities.nix;
  storageRoot = "/var/lib/radicale/collections";
  sharingDatabase = "${storageRoot}/collection-db/sharing.csv";
  davIdentityFile = builtins.toFile "essentials-dav-identities.json" (
    builtins.toJSON identities
  );
  reconcileDavShares = pkgs.writeShellApplication {
    name = "reconcile-essentials-dav-shares";
    runtimeInputs = [pkgs.python3];
    text = ''
      exec python3 ${./reconcile-essentials-dav-shares.py} \
        --identities ${davIdentityFile} \
        --storage ${storageRoot} \
        --database ${sharingDatabase}
    '';
  };
  notifyDav = pkgs.writeShellApplication {
    name = "notify-essentials-dav-change";
    runtimeInputs = [pkgs.curl];
    text = ''
      origin_device="''${1:-}"
      request_method="''${2:-}"
      case "$request_method" in
        PUT|DELETE|MKCOL|MKCALENDAR|PROPPATCH|MOVE) ;;
        *) exit 0 ;;
      esac
      payload='{"protocolVersion":1,"namespace":"dav"}'
      if [[ "$origin_device" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$ ]]; then
        payload="$(printf '{"protocolVersion":1,"namespace":"dav","originDeviceId":"%s"}' "$origin_device")"
      fi
      token_file=${config.sops.secrets."essentials-sync/invalidation-token".path}
      if [[ ! -r "$token_file" ]]; then
        echo "DAV invalidation token is unavailable" >&2
        exit 0
      fi
      token="$(<"$token_file")"
      if ! printf 'header = "Authorization: Bearer %s"\n' "$token" |
        curl --config - --fail --silent --show-error --max-time 5 \
        --header 'Content-Type: application/json' \
        --data "$payload" \
        http://10.70.0.1:8090/internal/v1/invalidate >/dev/null; then
        echo "DAV invalidation publish failed; periodic sync remains active" >&2
      fi
    '';
  };
in {
  assertions = [
    {
      assertion = lib.versionAtLeast (lib.getVersion pkgs.radicale) "3.7.0";
      message = "Essentials DAV collection mapping requires Radicale 3.7.0 or newer.";
    }
  ];

  services.radicale = {
    enable = true;
    settings = {
      server.hosts = ["10.70.0.1:5232"];

      auth = {
        type = "htpasswd";
        htpasswd_filename = config.sops.secrets."essentials-webdav/htpasswd".path;
        htpasswd_encryption = "bcrypt";
      };

      storage = {
        filesystem_folder = storageRoot;
        hook = "${notifyDav}/bin/notify-essentials-dav-change %(user)s %(request)s";
      };

      sharing = {
        type = "csv";
        database_path = sharingDatabase;
        collection_by_map = true;
        collection_by_token = false;
        permit_create_map = false;
        permit_create_token = false;
      };
    };

    rights = {
      root = {
        user = ".+";
        collection = "";
        permissions = "R";
      };

      principal = {
        user = ".+";
        collection = "{user}";
        permissions = "RW";
      };

      collections = {
        user = ".+";
        collection = "{user}/[^/]+";
        permissions = "rw";
      };
    };
  };

  systemd.services.radicale = {
    after = ["wireguard-wg0.service" "essentials-push.service"];
    requires = ["wireguard-wg0.service"];
    serviceConfig.ExecStartPre = ["${reconcileDavShares}/bin/reconcile-essentials-dav-shares"];
  };

  users.users.radicale.extraGroups = ["essentials-push"];
}
