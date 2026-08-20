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

  # enhanced kiosk tty
  environment.systemPackages = [pkgs.foot];
  fonts.packages = [pkgs.nerd-fonts.jetbrains-mono];
  services.cage = {
    enable = true;
    user = "louis";
    program = "${pkgs.foot}/bin/foot";
    extraArguments = ["-s"];
    environment = {
      XKB_DEFAULT_REPEAT_RATE = "15";
      XKB_DEFAULT_REPEAT_DELAY = "50";
    };
  };

  system.stateVersion = "24.05";
}
