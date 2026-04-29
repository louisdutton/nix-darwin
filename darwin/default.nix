{
  config,
  lib,
  user,
  ...
}: {
  # homedir fix
  users.users.${user.name}.home = "/Users/louis";

  # sys-dependant rebuild command
  environment.shellAliases = {
    clip = "pbcopy";
    rebuild = "sudo ${lib.getExe config.system.build.darwin-rebuild} switch --flake ~/projects/nix-darwin";
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
