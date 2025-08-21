{
  pkgs,
  user,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/configuration.nix
    ../../modules/desktop.nix
  ];

  networking.hostName = "ideapad";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  environment = {
    shellAliases = {
      rebuild = "sudo nixos-rebuild switch --flake ~/projects/nixos";
    };
  };

  system.stateVersion = "24.05";
}
