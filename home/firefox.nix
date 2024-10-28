{
  inputs,
  pkgs,
  ...
}:
let
  lock = Value: {
    inherit Value;
    Status = "locked";
  };
in
{

  programs.firefox = {
    enable = true;
    package = pkgs.firefox-devedition-bin;

    # enable native communication for tridactyl extension
    nativeMessagingHosts = with pkgs; [
      tridactyl-native
    ];

    # about:policies#documentation.
    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DontCheckDefaultBrowser = true;
      DisablePocket = true;
      DisableAccounts = true;
      DisableFirefoxAccounts = true;
      DisplayBookmarksToolbar = "never";
      DisplayMenuBar = "never";
      SearchBar = "unified";
      OverrideFirstRunPage = "";
      OverridePostUpdatePage = "";
      PasswordManagerEnabled = false;
    };

    profiles = {
      default = {
        extensions = with inputs.firefox-addons.packages.${pkgs.system}; [
          proton-pass
          tridactyl
        ];

        # about:config
        settings =
          builtins.mapAttrs (name: value: lock value) {
            #	disable builtin extensions
            "extensions.screenshots.disabled" = true;
            "extensions.pocket.enabled" = false;
            "extensions.autoDisableScopes" = 0;

            # warnings
            "browser.aboutConfig.showWarning" = false;
            "browser.warnOnQuit" = false;
            "browser.warnOnQuitShortcut" = false;

            # browser misc
            "browser.topsites.contile.enabled" = false;
            "browser.formfill.enable" = false;

            # search
            "browser.search.suggest.enabled" = false;
            "browser.search.suggest.enabled.private" = false;
            "browser.urlbar.suggest.searches" = false;
            "browser.urlbar.showSearchSuggestionsFirst" = false;

            # newtabpage
            "browser.newtabpage.activity-stream.telemetry" = false;
            "browser.newtabpage.activity-stream.feeds.telemetry" = false;
            "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
            "browser.newtabpage.activity-stream.feeds.snippets" = false;
            "browser.newtabpage.activity-stream.section.highlights.includePocket" = false;
            "browser.newtabpage.activity-stream.section.highlights.includeBookmarks" = false;
            "browser.newtabpage.activity-stream.section.highlights.includeDownloads" = false;
            "browser.newtabpage.activity-stream.section.highlights.includeVisited" = false;
            "browser.newtabpage.activity-stream.showSponsored" = false;
            "browser.newtabpage.activity-stream.system.showSponsored" = false;
            "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;

            # custom theme compat
            "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
            "layers.acceleration.force-enabled" = true;
            "gfx.webrender.all" = true;

            # font
            "font.default.x-western" = "monospace";
            "font.name.monospace.x-western" = "JetBrainsMono Nerd Font";
          }
          //
          # unlocked
          {
            "browser.contentblocking.category" = true; # "strict" breaks many sites

            # insecurely remove extension restrictions
            "privacy.resistFingerprinting.block_mozAddonManager" = true;
            "extensions.webextensions.restrictedDomains" = "";
          };

        userChrome = builtins.readFile ./userChrome.css;
        userContent = builtins.readFile ./userContent.css;
      };
    };
  };

  home.file.".config/tridactyl/tridactylrc".text = builtins.readFile ./tridactylrc;
}
