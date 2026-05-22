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
          # Bootstrap profile for Louis' first remote device.
          publicKey = "kai0tDVE+sbd73IXSNrhfCR35uFK8zLZrACMkn5yry8=";
          allowedIPs = ["10.70.0.2/32"];
        }
      ];
    };
  };
}
