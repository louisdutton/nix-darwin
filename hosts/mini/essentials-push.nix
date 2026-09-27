{config, ...}: let
  interface = "wg0";
  listenAddress = "10.70.0.1";
  publicPort = 8092;
  internalPort = 8093;
in {
  services.ntfy-sh = {
    enable = true;
    settings = {
      base-url = "http://${listenAddress}:${toString publicPort}";
      listen-http = "127.0.0.1:${toString internalPort}";
      cache-file = "/var/lib/ntfy-sh/cache.db";
      cache-duration = "24h";
      enable-login = false;
      enable-signup = false;
    };
  };

  # Android uses the same person credential for DAV and instant delivery.
  # ntfy stays loopback-only; Apache enforces the shared htpasswd file.
  services.httpd = {
    enable = true;
    extraModules = ["headers" "proxy" "proxy_http"];
    virtualHosts."essentials-push" = {
      hostName = "essentials-push";
      listen = [
        {
          ip = listenAddress;
          port = publicPort;
        }
      ];
      extraConfig = ''
        ProxyPass / http://127.0.0.1:${toString internalPort}/ nocanon
        ProxyPassReverse / http://127.0.0.1:${toString internalPort}/
        <Location "/">
          AuthType Basic
          AuthName "Essentials"
          AuthBasicProvider file
          AuthUserFile "${config.sops.secrets."essentials-webdav/htpasswd".path}"
          Require valid-user
          RequestHeader unset Authorization
        </Location>
      '';
    };
  };

  networking.firewall.interfaces.${interface}.allowedTCPPorts = [publicPort];
}
