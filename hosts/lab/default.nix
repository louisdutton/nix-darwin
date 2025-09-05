{pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix
    # ./matrix.nix
  ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "homelab";

  environment.systemPackages = with pkgs; [
    vim
  ];
  networking.firewall.allowedTCPPorts = [22];
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  system.stateVersion = "24.11";
}
