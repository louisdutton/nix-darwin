{
  inputs,
  pkgs,
  user,
  ...
}: let
  theatreKodi =
    (import ../../pkgs/kodi {
      inherit pkgs;
      homeDirectory = "/home/${user.name}";
    }).package;
in {
  imports = [
    inputs.disko.nixosModules.disko
    ./disk-config.nix
    ./hardware-configuration.nix
    ./wireguard.nix
    ../../modules/configuration.nix
    ../../modules/inputplumber.nix
    ../../modules/sops.nix
  ];

  networking.hostName = "theatre";
  networking.firewall.enable = true;

  nixpkgs.config.allowUnfree = true;

  home-manager.users.${user.name}.imports = [../../home/kodi.nix];

  environment.shellAliases.rebuild = "sudo nixos-rebuild switch --flake ~/projects/nixos";

  security.sudo.extraRules = [
    {
      users = [user.name];
      commands = [
        {
          command = "${pkgs.nixos-rebuild}/bin/nixos-rebuild";
          options = ["NOPASSWD"];
        }
        {
          command = "/run/current-system/sw/bin/nixos-rebuild";
          options = ["NOPASSWD"];
        }
        {
          command = "/run/current-system/sw/bin/systemctl restart display-manager.service";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];

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

  services.inputplumber = {enable = true;} // import ../../config/kodi/inputplumber.nix;
  services.logind.settings.Login.IdleAction = "ignore";
  services.udev.packages = [
    # Run before seat ACLs are assigned. InputPlumber only needs evdev;
    # Steam must not bypass its capture through the physical HIDAPI device.
    (pkgs.writeTextDir "lib/udev/rules.d/70-theatre-controller.rules" ''
      SUBSYSTEM=="hidraw", KERNELS=="*057E:2009*", MODE="0600", OWNER="root", GROUP="root", TAG-="uaccess"
    '')
  ];
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id === "org.shadowblip.Input.CompositeDevice.LoadProfilePath" &&
          subject.user === "${user.name}" && subject.local && subject.active) {
        return polkit.Result.YES;
      }
    });
  '';

  # SDDM launches Gamescope directly; it owns the TV and native Wayland Kodi.
  services.displayManager = {
    sessionPackages = [
      (import ../../pkgs/kodi/gamescope.nix {
        inherit pkgs;
        kodi = theatreKodi;
        # Gamescope otherwise selects the boot iGPU, which has no TV output.
        vulkanDevice = "1002:7550"; # Radeon RX 9070 XT
      })
    ];
    sddm = {
      enable = true;
      wayland.enable = true;
    };
    defaultSession = "theatre-gamescope";
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
      package = pkgs.steam.override {
        extraEnv = {
          SDL_JOYSTICK_HIDAPI_SWITCH = "0";
          SDL_GAMECONTROLLER_IGNORE_DEVICES = "0x057e/0x2009";
          SteamNoOverlayUI = "1";
        };
      };
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
    (import ../../pkgs/kodi/tv.nix {inherit pkgs;})
    (import ../../pkgs/gog {inherit pkgs;})
    (writeShellScriptBin "kodi-steam" ''
      unset LD_PRELOAD
      exec ${theatreKodi}/bin/kodi -fs "$@"
    '')
    mangohud
  ];

  # Pulse-Eight USB-CEC adapter access without granting all serial devices.
  # Explicit ownership permits recovery over SSH even when Kodi's seat is gone.
  services.udev.extraRules = ''
    SUBSYSTEM=="tty", ATTRS{idVendor}=="2548", ATTRS{idProduct}=="1002", OWNER="${user.name}", MODE="0600"
  '';

  system.stateVersion = "26.05";
}
