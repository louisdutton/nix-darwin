{
  inputs,
  lib,
  ...
}: {
  imports = [
    inputs.apple-silicon.nixosModules.apple-silicon-support
  ];

  nixpkgs.overlays = [inputs.apple-silicon.overlays.apple-silicon-overlay];

  hardware.asahi = {
    enable = true;
    peripheralFirmwareDirectory = /boot/vendorfw;
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  # wpa_supplicant doesn't work on asahi
  networking.networkmanager.wifi.backend = lib.mkForce "iwd";
}
