{pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix
    ./matrix.nix
    ../../modules/sops.nix
  ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  environment.systemPackages = with pkgs; [
    vim
  ];

  networking.hostName = "homelab";
  networking.firewall.allowedTCPPorts = [22];
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  documentation.enable = false;
  system.stateVersion = "24.11";

  services.jellyfin.enable = true;
  services.jellyfin.openFirewall = true;
}
