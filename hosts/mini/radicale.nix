{config, ...}: {
  sops.secrets."radicale/htpasswd" = {
    owner = "radicale";
    group = "radicale";
    mode = "0440";
  };

  services.radicale = {
    enable = true;
    settings = {
      server.hosts = ["10.70.0.1:5232"];

      auth = {
        type = "htpasswd";
        htpasswd_filename = config.sops.secrets."radicale/htpasswd".path;
        htpasswd_encryption = "bcrypt";
      };

      storage.filesystem_folder = "/var/lib/radicale/collections";
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
    after = ["wireguard-wg0.service"];
    requires = ["wireguard-wg0.service"];
  };
}
