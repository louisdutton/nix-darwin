{
  pkgs,
  user,
  inputs,
  config,
  lib,
  ...
}: {
  # nix
  nix = {
    nixPath = ["nixpkgs=${inputs.nixpkgs}"];
    channel.enable = false; # flakes > channels
    optimise.automatic = true;
    gc.automatic = true;
    settings.experimental-features = [
      "nix-command"
      "flakes"
      "pipe-operators"
    ];
  };

  # users
  time.timeZone = "Europe/London";
  networking.hostName = "nixos";
  users.users.${user.name} = {
    description = user.displayName;
    home = "/Users/${user.name}";
  };

  # aliases and custom utils
  environment = {
    shellAliases = {
      e = "$EDITOR";
      g = "lazygit";
      clean = "git clean -xdf";
      l = "ls";
      la = "ls -a";
      ll = "ls -l";
      clip = "pbcopy";
      rebuild = "sudo ${lib.getExe config.system.build.darwin-rebuild} switch --flake ~/projects/nix-darwin";
    };

    systemPackages = with pkgs; [
    ];
  };

  # own zsh's system startup files so login and non-login shells share nix-darwin's environment
  programs.zsh = {
    enable = true;
    shellInit = ''
      if [[ ":$PATH:" != *":/etc/profiles/per-user/$USER/bin:"* ]]; then
        unset __NIX_DARWIN_SET_ENVIRONMENT_DONE
        . ${config.system.build.setEnvironment}
      fi
    '';
  };

  environment.shellAliases = {
  };

  # tailscale
  services.tailscale.enable = true;

  system = {
    primaryUser = "louis";
    # check `man configuration.nix` before changing
    stateVersion = 6;

    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToEscape = true;
    };

    defaults.CustomUserPreferences.NSGlobalDomain = {
      # keyboard
      AppleKeyboardUIMode = 3; # full keyboard control
      ApplePressAndHoldEnabled = false;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      InitialKeyRepeat = 10; # 150ms
      KeyRepeat = 1; # 15ms
    };
  };
}
