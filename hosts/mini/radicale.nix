{
  config,
  lib,
  pkgs,
  ...
}: let
  identities = import ./essentials-identities.nix;
  storageRoot = "/var/lib/radicale/collections";
  collectionRoot = "${storageRoot}/collection-root";
  csvFields = [
    "ShareType"
    "PathOrToken"
    "PathMapped"
    "Conversion"
    "Owner"
    "User"
    "Permissions"
    "EnabledByOwner"
    "EnabledByUser"
    "HiddenByOwner"
    "HiddenByUser"
    "TimestampCreated"
    "TimestampUpdated"
    "Properties"
    "Actions"
  ];
  shareRow = user: group: collection:
    lib.concatStringsSep ";" [
      "map"
      "/${user}/${group}-${collection}/"
      "/${group}/${collection}/"
      "none"
      group
      user
      "rw"
      "True"
      "True"
      "False"
      "False"
      "0"
      "0"
      ""
      ""
    ];
  sharingRows = lib.concatMap (
    group:
      lib.concatMap (
        user:
          map (collection: shareRow user group collection) (
            lib.attrNames identities.davCollections.groups.${group}
          )
      ) identities.groups.${group}.members
  ) (lib.attrNames identities.groups);
  sharingDatabase = pkgs.writeText "essentials-radicale-sharing.csv" (
    lib.concatLines ([(lib.concatStringsSep ";" csvFields)] ++ sharingRows)
  );
  collectionProperties = spec:
    {
      inherit (spec) tag;
      "D:displayname" = spec.displayName;
    }
    // lib.optionalAttrs (spec ? components) {
      "C:supported-calendar-component-set" = lib.concatStringsSep "," spec.components;
    };
  collectionRules = owners:
    lib.concatLists (
      lib.mapAttrsToList (
        owner: collections:
          ["d ${collectionRoot}/${owner} 0750 radicale radicale - -"]
          ++ lib.concatLists (
            lib.mapAttrsToList (
              collection: spec: [
                "d ${collectionRoot}/${owner}/${collection} 0750 radicale radicale - -"
                "f ${collectionRoot}/${owner}/${collection}/.Radicale.props 0640 radicale radicale - - ${builtins.toJSON (collectionProperties spec)}"
              ]
            ) collections
          )
      ) owners
    );
  notifyDav = pkgs.writeShellApplication {
    name = "notify-essentials-dav-change";
    runtimeInputs = [pkgs.curl];
    text = ''
      request_method="''${1:-}"
      case "$request_method" in
        PUT|DELETE|MKCOL|MKCALENDAR|PROPPATCH|MOVE) ;;
        *) exit 0 ;;
      esac
      payload='{"protocolVersion":1,"namespace":"dav"}'
      if ! curl --fail --silent --show-error --max-time 5 \
        --header 'Content-Type: application/json' \
        --data "$payload" \
        http://127.0.0.1:8093/essentials-sync >/dev/null; then
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
        hook = "${notifyDav}/bin/notify-essentials-dav-change %(request)s";
      };

      sharing = {
        type = "csv";
        database_path = toString sharingDatabase;
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

  # Create canonical collection directories and metadata only when absent.
  # The `f` tmpfiles rule never replaces existing metadata or collection data.
  systemd.tmpfiles.rules =
    collectionRules identities.davCollections.users
    ++ collectionRules identities.davCollections.groups;

  systemd.services.radicale = {
    after = ["wireguard-wg0.service" "ntfy-sh.service"];
    requires = ["wireguard-wg0.service"];
  };
}
