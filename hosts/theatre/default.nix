{
  inputs,
  pkgs,
  user,
  ...
}: {
  imports = [
    inputs.disko.nixosModules.disko
    ./disk-config.nix
    ./hardware-configuration.nix
    ../../modules/configuration.nix
  ];

  networking.hostName = "theatre";
  networking.firewall.enable = true;

  nixpkgs.config.allowUnfree = true;

  users.users.${user.name} = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJkTqlA9tbOrjytaN+8hAyPVWgrqucBMJSFBsswNtVug louis@ideapad"
    ];
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelModules = ["hid-nintendo"];

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    # Expose controller battery information to Steam and other clients.
    settings.General.Experimental = true;
  };

  # SDDM only launches the session; no desktop environment is installed.
  services.displayManager = {
    sddm = {
      enable = true;
      wayland.enable = true;
    };
    defaultSession = "steam";
    autoLogin = {
      enable = true;
      user = user.name;
    };
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  programs = {
    gamemode.enable = true;
    gamescope = {
      enable = true;
      # Steam's bubblewrap sandbox refuses inherited ambient capabilities.
      # GameMode still handles per-game performance tuning.
      capSysNice = false;
    };
    steam = {
      enable = true;
      gamescopeSession = {
        enable = true;
        # Use Steam's Deck UI rather than legacy ten-foot mode. This exposes
        # per-game Steam Play/Proton controls and SteamOS-integrated settings.
        steamArgs = [
          "-gamepadui"
          "-steamos3"
          "-steampal"
          "-steamdeck"
          "-pipewire-dmabuf"
        ];
      };
      remotePlay.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
    };
  };

  services.fwupd.enable = true;
  services.fstrim.enable = true;
  zramSwap.enable = true;

  environment.systemPackages = with pkgs; [
    heroic
    mangohud
  ];

  system.stateVersion = "26.05";
}
