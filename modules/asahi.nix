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

  boot.loader.systemd-boot = {
    enable = true;
    # The Asahi ESP is small and each NixOS generation adds a kernel and initrd.
    configurationLimit = 3;
  };
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  # wpa_supplicant doesn't work on asahi
  networking.networkmanager.wifi.backend = lib.mkForce "iwd";
}
