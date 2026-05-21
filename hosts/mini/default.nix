{config, ...}: {
  imports = [
    ./hardware-configuration.nix
    ./matrix.nix
    ./wireguard.nix
    ../../modules/configuration.nix
    ../../modules/asahi.nix
    ../../modules/sops.nix
  ];

  networking.hostName = "mini";
  services.openssh.enable = true;

  # bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General.Experimental = true; # enable device battery status
  };

  environment = {
    shellAliases = {
      rebuild = "sudo nixos-rebuild switch --impure --flake ~/projects/nixos";
    };
  };

  services.tailscale = {
    enable = true;
    permitCertUid = "caddy";
  };

  # Caddy reverse proxy with Tailscale HTTPS
  services.caddy = {
    enable = true;
    virtualHosts."mini.taila65fcf.ts.net" = {};
  };

  # network-level adblock
  services.pihole-ftl = {
    enable = true;
    openFirewallDHCP = true;
    openFirewallDNS = true;

    # See <https://docs.pi-hole.net/ftldns/configfile/>
    settings = {
      dns.upstreams = ["9.9.9.9" "1.1.1.1"];

      # potentially move dns aliases for here
      # dns.hosts = ["192.168.1.xxx mini"];
    };
  };

  swapDevices = [
    {
      device = "/swapfile";
      size = 8192; # MB
    }
  ];

  system.stateVersion = "25.11";
}
