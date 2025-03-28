{
  user,
  ...
}:
{
  imports = [
    ./aerospace.nix
    ./sketchybar.nix
    ./jankyborders.nix
  ];

  # disable nix channels as we are using flakes
  nix.channel.enable = false;

  # homedir fix
  users.users.${user.name}.home = "/Users/louis";

  # sys-dependant rebuild command
  environment.shellAliases = {
    clip = "pbcopy";
    rebuild = "darwin-rebuild switch --flake ~/.config/nix-darwin";
  };

  system = {
    # check `man configuration.nix` before changing
    stateVersion = 5;

    startup.chime = false;

    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToEscape = true;
    };

    defaults.CustomUserPreferences = {
      NSGlobalDomain = {
        WebKitDeveloperExtras = true; # Add a context menu item for showing the Web Inspector in web views

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

        InitialKeyRepeat = 10; # 150ms
        KeyRepeat = 1; # 15ms

        NSNavPanelExpandedStateForSaveMode = true;
        NSNavPanelExpandedStateForSaveMode2 = true;

        # improve experience in tiling window managers
        NSAutomaticWindowAnimationsEnabled = false;
        NSWindowResizeTime = 0.0;
        NSUseAnimatedFocusRing = false;
        _HIHideMenuBar = true;

        "com.apple.sound.beep.volume" = 0.0; # disable beep / alert sound
      };

      "com.apple.dock" = {
        autohide = true;
        static-only = true;
        launchanim = false;
        dashboard-in-overlay = false;
      };

      "com.apple.finder" = {
        QuitMenuItem = true;
        AppleShowAllFiles = true;
        AppleShowAllExtensions = true;
        ShowPathbar = true;
        ShowExternalHardDrivesOnDesktop = true;
        ShowHardDrivesOnDesktop = true;
        ShowMountedServersOnDesktop = true;
        ShowRemovableMediaOnDesktop = true;
        FXDefaultSearchScope = "SCcf"; # current folder
        _FXSortFoldersFirst = true;
        _FXShowPosixPathInTitle = true;
      };

      "com.apple.desktopservices" = {
        # Avoid creating .DS_Store files on network or USB volumes
        DSDontWriteNetworkStores = true;
        DSDontWriteUSBStores = true;
      };

      "com.apple.screensaver" = {
        # Require password immediately after sleep or screen saver begins
        askForPassword = 1;
        askForPasswordDelay = 0;
      };

      "com.apple.screencapture" = {
        location = "~/Desktop";
        type = "png";
      };

      "com.apple.Safari.SandboxBroker" = {
        ShowDevelopMenu = true;
      };

      "com.apple.Safari" = {
        HomePage = "https://github.com";

        # interface
        ShowFullURLInSmartSearchField = true;
        ShowFavoritesBar = false;
        ShowStandaloneTabBar = 0;

        # privacy
        UniversalSearchEnabled = false; # don’t send search queries to Apple
        SuppressSearchSuggestions = true;
        HideIPAddressFromTrackers = true;
        "PrivacySettings.crossSiteTracking" = false;

        # security
        AutoOpenSafeDownloads = false;
        WarnAboutFraudulentWebsites = true;

        # spellcheck
        WebContinuousSpellCheckingEnabled = true;
        WebAutomaticSpellingCorrectionEnabled = false;

        # disable
        AutoFillFromAddressBook = false;
        AutoFillCreditCardData = false;
        AutoFillMiscellaneousForms = false;

        # dev
        IncludeInternalDebugMenu = true;
        IncludeDevelopMenu = true;
        "WebKitPreferences.developerExtrasEnabled" = true;
        WebKitTabToLinksPreferenceKey = true; # Press Tab to highlight each item on a web page
        WebKitDeveloperExtrasEnabledPreferenceKey = true;
        WebKitJavaEnabled = false;
        WebKitJavaScriptCanOpenWindowsAutomatically = false;
        "com.apple.Safari.ContentPageGroupIdentifier.WebKit2TabsToLinks" = true;
        "com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled" = true;
        "com.apple.Safari.ContentPageGroupIdentifier.WebKit2BackspaceKeyNavigationEnabled" = false;
        "com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaEnabled" = false;
        "com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaEnabledForLocalFiles" = false;
        "com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaScriptCanOpenWindowsAutomatically" = false;
      };

      "com.apple.SoftwareUpdate" = {
        AutomaticCheckEnabled = true;
        AutomaticDownload = 1;
        ScheduleFrequency = 1; # daily
        CriticalUpdateInstall = 1; # install system data files & security updates
      };

      # disable fingerprinting
      "com.apple.AdLib" = {
        allowApplePersonalizedAdvertising = false;
        allowIdentifierForAdvertising = false;
      };

      "com.apple.mail".DisableInlineAttachmentViewing = true;
      "com.apple.print.PrintingPrefs"."Quit When Finished" = true; # automatically quit printer app once the print jobs complete
      "com.apple.TimeMachine".DoNotOfferNewDisksForBackup = true;
      "com.apple.ImageCapture".disableHotPlug = true; # prevent auto-opening photos when device plugged in
      "com.apple.commerce".AutoUpdate = true; # auto-update apps
      "com.apple.WindowManager".EnableStandardClickToShowDesktop = false; # disable desktop click
    };

    activationScripts = {
      # set wallpaper on all displays
      wallpaper.text = ''
        osascript -e "tell application \"System Events\" to tell every desktop to set picture to \"/Users/louis/.config/nix-darwin/wallpapers/waves.jpg\" as POSIX file"
      '';

      # apply nix-darwin configuration without restart
      postUserActivation.text = ''
        /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
      '';
    };
  };

}
