{
  pkgs,
  user,
  ...
}:
{
  imports = [
    ./yabai.nix
    ./skhd.nix
    ./sketchybar.nix
    ./jankyborders.nix
    ./choose.nix
  ];

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;

  # disable nix channels as we are using flakes
  nix.channel.enable = false;

  # homedir fix
  users.users.${user.name}.home = "/Users/louis";

  environment = {
    systemPackages = with pkgs; [
      alacritty
      slack
    ];

    shellAliases = {
      rebuild = "sudo darwin-rebuild switch --flake ~/.config/nix-darwin";
    };
  };

  system = {
    checks.verifyNixChannels = false;
    startup.chime = false;

    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToEscape = true;
    };

    defaults = {
      screencapture.location = "/tmp";

      dock = {
        autohide = true;
        static-only = true;
        launchanim = false;
        dashboard-in-overlay = false;
      };

      finder = {
        QuitMenuItem = true;
        AppleShowAllFiles = true;
        AppleShowAllExtensions = true;
        ShowPathbar = true;
        _FXShowPosixPathInTitle = true;
      };

      # disable desktop click 
      WindowManager.EnableStandardClickToShowDesktop = false;

      NSGlobalDomain = {
        AppleInterfaceStyle = "Dark";
        AppleShowAllFiles = true;

        # keyboard
        AppleKeyboardUIMode = 3; # full keyboard control
        ApplePressAndHoldEnabled = false;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticDashSubstitutionEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticQuoteSubstitutionEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;

        # ms = x: x * 15
        InitialKeyRepeat = 10;
        KeyRepeat = 1;

        NSNavPanelExpandedStateForSaveMode = true;
        NSNavPanelExpandedStateForSaveMode2 = true;

        # improve experience in tiling window managers
        NSAutomaticWindowAnimationsEnabled = false;
        NSWindowResizeTime = 0.0;
        NSUseAnimatedFocusRing = false;
        _HIHideMenuBar = true;

        "com.apple.sound.beep.volume" = 0.0; # disable beep / alert sound
      };
    };

    # check `man configuration.nix` before changing
    stateVersion = 5;
  };

  # set wallpaper on all displays
  system.activationScripts.wallpaper = {
    enable = true;
    text = ''
      osascript -e "tell application \"System Events\" to tell every desktop to set picture to \"/Users/louis/.config/nix-darwin/wallpapers/ocean.png\" as POSIX file"
    '';
  };
}
