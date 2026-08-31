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

  environment.shellAliases.rebuild =
    "sudo nixos-rebuild switch --flake ~/projects/nixos";

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
    # Otherwise BlueZ replaces General.Name with networking.hostName.
    disabledPlugins = ["hostname"];
    settings.General = {
      # Expose controller battery information to Steam and other clients.
      Experimental = true;
      # Nintendo controllers use a less reliable generic-host mode unless the
      # Bluetooth host name looks like a Switch, leading to dropped reports and
      # eventual disconnects.
      Name = "Nintendo Switch";
    };
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
    (symlinkJoin {
      name = "heroic-steam";
      paths = [ heroic ];
      nativeBuildInputs = [ makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/heroic \
          --unset LD_PRELOAD \
          --add-flags "--disable-gpu --no-sandbox"
      '';
    })
    mangohud
  ];

  system.stateVersion = "26.05";
}
