{
  config,
  pkgs,
  ...
}: let
  interface = "wg0";
in {
  environment.systemPackages = [pkgs.wireguard-tools];

  sops.secrets."wireguard/theatre-private-key" = {};

  networking = {
    firewall.trustedInterfaces = [interface];

    wireguard.interfaces.${interface} = {
      ips = ["10.70.0.3/24"];
      privateKeyFile = config.sops.secrets."wireguard/theatre-private-key".path;

      peers = [
        {
          # Mini routes the rest of the private WireGuard network, including
          # the phones, while local internet traffic keeps its normal route.
          publicKey = "NOBGYbQhMT8/MjgsO8aMMXf82saSZQwoMq+FlC4gogE=";
          allowedIPs = ["10.70.0.0/24"];
          endpoint = "mini.lan:51820";
          persistentKeepalive = 25;
        }
      ];
    };
  };
}
