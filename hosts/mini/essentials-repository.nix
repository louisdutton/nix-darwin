{pkgs, ...}: let
  interface = "wg0";
  listenAddress = "10.70.0.1";
  port = 8080;
  repositoryRoot = "/var/lib/essentials-repository";
in {
  environment.systemPackages = [pkgs.rsync];

  users.groups.essentials-repository.members = [
    "louis"
    "caddy"
  ];

  systemd.tmpfiles.rules = [
    "d ${repositoryRoot} 2770 louis essentials-repository - -"
    "d ${repositoryRoot}/releases 2770 louis essentials-repository - -"
  ];

  services.caddy = {
    enable = true;
    virtualHosts."http://${listenAddress}:${toString port}".extraConfig = ''
      bind ${listenAddress}
      root * ${repositoryRoot}/current
      header Cache-Control "no-cache"
      file_server
    '';
  };

  systemd.services.caddy = {
    after = ["wireguard-${interface}.service"];
    requires = ["wireguard-${interface}.service"];
  };

  networking.firewall.interfaces.${interface}.allowedTCPPorts = [port];
}
