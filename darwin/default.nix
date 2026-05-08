{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  launchdWrapperDir = "/Library/Application Support/nix-darwin/launchd-wrappers";

  mkLaunchdWrapper = name: command:
    pkgs.writeText "nix-darwin-${name}-launchd-wrapper" ''
      #!/bin/sh
      /bin/wait4path /nix/store || exit 1
      exec ${command} "$@"
    '';

  launchdWrappers =
    {
      activate-system = {
        label = "org.nixos.activate-system";
        plist = "org.nixos.activate-system.plist";
        target = "${launchdWrapperDir}/activate-system";
        source = mkLaunchdWrapper "activate-system" config.launchd.daemons.activate-system.command;
      };

      nix-daemon = {
        label = "org.nixos.nix-daemon";
        plist = "org.nixos.nix-daemon.plist";
        target = "${launchdWrapperDir}/nix-daemon";
        source = mkLaunchdWrapper "nix-daemon" config.launchd.daemons.nix-daemon.command;
      };
    }
    // lib.optionalAttrs config.nix.gc.automatic {
      nix-gc = {
        label = "org.nixos.nix-gc";
        plist = "org.nixos.nix-gc.plist";
        target = "${launchdWrapperDir}/nix-gc";
        source = mkLaunchdWrapper "nix-gc" config.launchd.daemons.nix-gc.command;
      };
    }
    // lib.optionalAttrs config.nix.optimise.automatic {
      nix-optimise = {
        label = "org.nixos.nix-optimise";
        plist = "org.nixos.nix-optimise.plist";
        target = "${launchdWrapperDir}/nix-optimise";
        source = mkLaunchdWrapper "nix-optimise" config.launchd.daemons.nix-optimise.command;
      };
    }
    // lib.optionalAttrs config.services.tailscale.enable {
      tailscaled = {
        label = "com.tailscale.tailscaled";
        plist = "com.tailscale.tailscaled.plist";
        target = "${launchdWrapperDir}/tailscaled";
        source = mkLaunchdWrapper "tailscaled" config.launchd.daemons.tailscaled.command;
      };
    };

  installLaunchdWrappers =
    lib.concatStringsSep "\n"
    (lib.mapAttrsToList (_: wrapper: ''
        install -m 0755 ${lib.escapeShellArg (toString wrapper.source)} ${lib.escapeShellArg wrapper.target}
      '')
      launchdWrappers);

  bootstrapLaunchdWrappers =
    lib.concatStringsSep "\n"
    (lib.mapAttrsToList (_: wrapper: ''
        launchctl enable system/${wrapper.label} || true
        if ! launchctl print system/${wrapper.label} >/dev/null 2>&1; then
          launchctl bootstrap system /Library/LaunchDaemons/${wrapper.plist} || true
        fi
      '')
      launchdWrappers);
in {
  # homedir fix
  users.users.${user.name}.home = "/Users/louis";

  # sys-dependant rebuild command
  environment.shellAliases = {
    clip = "pbcopy";
    rebuild = "sudo ${lib.getExe config.system.build.darwin-rebuild} switch --flake ~/projects/nix-darwin";
  };

  # tailscale
  services.tailscale.enable = true;

  # Keep launchd jobs identifiable in macOS Background Items. nix-darwin's
  # default wrapper uses `/bin/sh -c`, which macOS displays as a vague `sh`.
  system.activationScripts.extraActivation.text = lib.mkAfter ''
    install -d -m 0755 ${lib.escapeShellArg launchdWrapperDir}
    ${installLaunchdWrappers}
  '';

  system.activationScripts.launchd.text = lib.mkAfter ''
    ${bootstrapLaunchdWrappers}
  '';

  launchd.daemons =
    lib.mapAttrs (_: wrapper: {
      serviceConfig.ProgramArguments = lib.mkForce [wrapper.target];
    })
    launchdWrappers;

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
