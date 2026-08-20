{
  config,
  pkgs,
  ...
}: let
  interface = "wg0";
  lanInterface = "wlan0";
  port = 51820;
in {
  environment.systemPackages = [pkgs.wireguard-tools];

  sops.secrets."wireguard/mini-private-key" = {};

  networking = {
    tempAddresses = "disabled";

    firewall = {
      allowedUDPPorts = [port];
      trustedInterfaces = [interface];
    };

    nat = {
      enable = true;
      externalInterface = lanInterface;
      internalInterfaces = [interface];
    };

    wireguard.interfaces.${interface} = {
      ips = ["10.70.0.1/24"];
      listenPort = port;
      privateKeyFile = config.sops.secrets."wireguard/mini-private-key".path;

      peers = [
        {
          # louis mobile.
          publicKey = "kai0tDVE+sbd73IXSNrhfCR35uFK8zLZrACMkn5yry8=";
          allowedIPs = ["10.70.0.2/32"];
        }
        {
          # hollie's mobile.
          publicKey = "LveL8SjK9ggMWWrAvWmuIelIUjJBtW0rkKl3q1gq5lE=";
          allowedIPs = ["10.70.0.4/32"];
        }
      ];
    };
  };
}
