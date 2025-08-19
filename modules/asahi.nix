{inputs, lib, ...}: {
  imports = [
    inputs.apple-silicon.nixosModules.apple-silicon-support
  ];

  nixpkgs.overlays = [inputs.apple-silicon.overlays.apple-silicon-overlay];
  hardware.asahi.useExperimentalGPUDriver = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.backend = "iwd"; # wpa_supplicant doesn't work on asahi
}
