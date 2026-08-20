{pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/configuration.nix
    ../../modules/sops.nix
    # ../../modules/desktop.nix
  ];

  networking.hostName = "ideapad";

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

  environment.systemPackages = with pkgs; [
    foot
    zellij

    # agent
    codex
    bubblewrap
  ];

  system.stateVersion = "24.05";
}
