{...}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/configuration.nix
    ../../modules/asahi.nix
    ../../modules/desktop.nix
    ../../modules/sops.nix
    ../../modules/games.nix
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

  system.stateVersion = "25.11";
}
