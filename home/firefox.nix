{
  inputs,
  pkgs,
  config,
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
  home.file.".config/tridactyl/themes/everforest.css".text = with config.lib.stylix.colors; ''
        :root {
    			/* base16 */
    			--base00: #${base00};
    			--base01: #${base01};
    			--base02: #${base02};
    			--base03: #${base03};
    			--base04: #${base04};
    			--base05: #${base05};
    			--base06: #${base06};
    			--base07: #${base07};
    			--base08: #${base08};
    			--base09: #${base09};
    			--base0A: #${base0A};
    			--base0B: #${base0B};
    			--base0C: #${base0C};
    			--base0D: #${base0D};
    			--base0E: #${base0E};
    			--base0F: #${base0F};

    			/* base */
    			--tridactyl-fg: var(--base05);
    			--tridactyl-bg: var(--base00);
    			--tridactyl-url-fg: var(--base08);
    			--tridactyl-url-bg: var(--base00);
    			--tridactyl-highlight-box-bg: var(--base0B);
    			--tridactyl-highlight-box-fg: var(--base00);

    			/* hint character tags */
    			--tridactyl-hintspan-fg: var(--base00) !important;
    			--tridactyl-hintspan-bg: var(--base0A) !important;

    			/* inversions */
    			--tridactyl-of-fg: var(--base00);
    			--tridactyl-of-bg: var(--base05);

    			/* element highlights */
    			--tridactyl-hint-active-fg: none;
    			--tridactyl-hint-active-bg: none;
    			--tridactyl-hint-active-outline: none;
    			--tridactyl-hint-bg: none;
    			--tridactyl-hint-outline: none;

    			--tridactyl-border-radius: 5px;
        }

        :root.TridactylOwnNamespace {
        	scrollbar-width: thin;
        }

        :root.TridactylOwnNamespace a {
        	color: #3b84ef;
        }

        :root.TridactylOwnNamespace code {
        	background-color: #2a333c;
        	padding: 3px 7px;
        }

        :root #command-line-holder {
        	order: 1;
        }

        :root #command-line-holder,
        :root #tridactyl-input {
        	border-radius: var(--tridactyl-border-radius) !important;
        }

        :root #tridactyl-colon::before {
        	content: "";
        }

        :root #tridactyl-input {
        	width: 96%;
        	padding: 1rem;
        }

        :root #completions table {
        	font-weight: 200;
        	table-layout: fixed;
        	padding: 1rem;
        	padding-top: 0;
        }

        :root #completions > div {
        	max-height: calc(20 * var(--tridactyl-cmplt-option-height));
        	min-height: calc(10 * var(--tridactyl-cmplt-option-height));
        }

        :root #completions {
        	border: none !important;
        	font-family: var(--tridactyl-font-family);
        	order: 2;
        	margin-top: 10px;
        	border-radius: var(--tridactyl-border-radius);
        }

        :root #completions .HistoryCompletionSource table {
        	width: 100%;
        	border-spacing: 0;
        	table-layout: fixed;
        }

        :root #completions .BufferCompletionSource table {
        	width: unset;
        	font-size: unset;
        	border-spacing: unset;
        	table-layout: unset;
        }

        :root #completions table tr .title {
        	width: 50%;
        }

        :root #completions tr .documentation {
        	white-space: nowrap;
        	overflow: auto;
        	text-overflow: ellipsis;
        }

        :root #completions .sectionHeader {
        	background: transparent;
        	padding: 1rem 1rem 0.4rem !important;
        }

        :root #cmdline_iframe {
        	position: fixed !important;
        	bottom: unset;
        	top: 25% !important;
        	left: 10% !important;
        	z-index: 2147483647 !important;
        	width: 80% !important;
        	filter: drop-shadow(0px 0px 20px #000000) !important;
        	color-scheme: only light; /* Prevent Firefox from adding a white background on dark-mode sites */
        }

        :root .TridactylStatusIndicator {
        	position: fixed !important;
        	bottom: 10px !important;
        	right: 10px !important;
        	font-weight: 200 !important;
        	padding: 5px !important;
        }
  '';
}
