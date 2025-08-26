{...}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/configuration.nix
    ../../modules/desktop.nix
  ];

  users.users.hollie.isNormalUser = true;

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

  system.stateVersion = "24.05";
}
