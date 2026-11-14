{user, ...}: let
  projects = "/home/${user.name}/projects";
in {
  services.webdav = {
    enable = true;
    user = user.name;
    group = "users";
    settings = {
      # WireGuard authenticates clients and encrypts transport. Its interface is
      # already trusted by the firewall; do not open this port on LAN interfaces.
      address = "10.70.0.3";
      port = 8788;
      directory = projects;
      permissions = "R";
      users = [];
    };
  };

  systemd.services.webdav = {
    wants = ["wireguard-wg0.service"];
    after = ["wireguard-wg0.service"];
    startLimitIntervalSec = 0;
    serviceConfig = {
      RestartSec = "5s";
      # Keep the original project paths, including absolute links within them.
      # Other home directories and runtime secrets are absent from this root.
      RootDirectory = "/run/webdav-root";
      RuntimeDirectory = "webdav-root";
      RuntimeDirectoryMode = "0755";
      BindReadOnlyPaths = [
        "/nix/store"
        projects
      ];
      ProtectSystem = "strict";
      PrivateTmp = true;
      PrivateDevices = true;
      NoNewPrivileges = true;
      CapabilityBoundingSet = "";
      RestrictSUIDSGID = true;
      RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
      UMask = "0077";
    };
  };
}
