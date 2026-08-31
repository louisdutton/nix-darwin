{pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/configuration.nix
    ../../modules/sops.nix
    # ../../modules/desktop.nix
  ];

  networking.hostName = "ideapad";

  # Avoid latency spikes and packet loss during interactive LAN sessions.
  networking.networkmanager.wifi.powersave = false;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  environment = {
    shellAliases = {
      rebuild = "sudo nixos-rebuild switch --flake ~/projects/nixos";
    };
  };

  # performance optimisation
  powerManagement.cpuFreqGovernor = "performance";
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;

  # this machine doesn't have ssh setup
  sops.age.keyFile = "/home/louis/.config/sops/age/keys.txt";

  system.stateVersion = "24.05";
}
