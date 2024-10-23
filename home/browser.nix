{ inputs, pkgs, ... }:
{
  programs.firefox = {
    enable = true;
    package = pkgs.firefox-devedition-bin;

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
          vimium
          proton-pass
          # sideberry
        ];

        # about:config
        settings = {
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
          "extensions.screenshots.disabled" = true;
          "extensions.pocket.enabled" = false;
          "extensions.autoDisableScopes" = 0;
          "browser.contentblocking.category" = "strict";
          "browser.aboutConfig.showWarning" = false;
          "browser.warnOnQuit" = false;
          "browser.warnOnQuitShortcut" = false;
          "browser.topsites.contile.enabled" = false;
          "browser.formfill.enable" = false;
          "browser.search.suggest.enabled" = false;
          "browser.search.suggest.enabled.private" = false;
          "browser.urlbar.suggest.searches" = false;
          "browser.urlbar.showSearchSuggestionsFirst" = false;
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
        };

        userChrome = # css
          ''
            /*
            ┏━╸┏━┓┏┓╻┏━╸╻┏━╸╻ ╻┏━┓┏━┓╺┳╸╻┏━┓┏┓╻
            ┃  ┃ ┃┃┗┫┣╸ ┃┃╺┓┃ ┃┣┳┛┣━┫ ┃ ┃┃ ┃┃┗┫
            ┗━╸┗━┛╹ ╹╹  ╹┗━┛┗━┛╹┗╸╹ ╹ ╹ ╹┗━┛╹ ╹
            */

            /*
            ┏━┓╻╺┳┓┏━╸┏┓ ┏━╸┏━┓╻ ╻
            ┗━┓┃ ┃┃┣╸ ┣┻┓┣╸ ┣┳┛┗┳┛
            ┗━┛╹╺┻┛┗━╸┗━┛┗━╸╹┗╸ ╹
            */
            #sidebar-box #sidebar-header {
              visibility: collapse;
            }

            #sidebar-box {
              --uc-sidebar-width: 10px !important;
              --uc-sidebar-hover-width: 275px;
              --uc-autohide-sidebar-delay: 1s;
              position: relative;
              min-width: var(--uc-sidebar-width) !important;
              width: var(--uc-sidebar-width) !important;
              max-width: var(--uc-sidebar-width) !important;
              z-index:1;
            }

            #sidebar-box > #sidebar {
              transition: min-width 400ms linear var(--uc-autohide-sidebar-delay), 
                          opacity 400ms ease calc(var(--uc-autohide-sidebar-delay) + 100ms) !important;
              min-width: var(--uc-sidebar-width) !important;
              opacity: 0 !important;
              will-change: min-width, opacity;
            }

            #sidebar-box:hover > #sidebar {
              min-width: var(--uc-sidebar-hover-width) !important;
              opacity: 1 !important;
              transition-delay: 0s !important;
            }

            #sidebar-box > #sidebar-splitter, 
            #sidebar-splitter {
                display: none;
            }

            #sidebar-box {
              background: var(--lwt-accent-color) !important;
            }

            /*
            ┏━┓┏━┓╺┳┓╺┳┓╻┏┓╻┏━╸
            ┣━┛┣━┫ ┃┃ ┃┃┃┃┗┫┃╺┓
            ╹  ╹ ╹╺┻┛╺┻┛╹╹ ╹┗━┛
            ┏━┓╻ ╻┏━┓┏━┓┏━┓╻ ╻┏┓╻╺┳┓
            ┗━┓┃ ┃┣┳┛┣┳┛┃ ┃┃ ┃┃┗┫ ┃┃
            ┗━┛┗━┛╹┗╸╹┗╸┗━┛┗━┛╹ ╹╺┻┛
            */

            @media not all and (display-mode: fullscreen) {
              #appcontent .browserStack,
              #browser,
              .browserContainer {
                background: var(--lwt-accent-color)
              }

              #browser > #appcontent {
                --margin: 10px;  

                margin-left: 0px;
                margin-right: var(--margin);
                margin-top: 0px;
                margin-bottom: var(--margin);
              
                browser {
                  --outline: 1px solid var(--arrowpanel-background);
                  border: var(--outline);
                }
              }
            }

            /*
            ┏━╸┏━┓┏┓╻╺┳╸┏━╸╻ ╻╺┳╸
            ┃  ┃ ┃┃┗┫ ┃ ┣╸ ┏╋┛ ┃
            ┗━╸┗━┛╹ ╹ ╹ ┗━╸╹ ╹ ╹
            ┏┳┓┏━╸┏┓╻╻ ╻
            ┃┃┃┣╸ ┃┗┫┃ ┃
            ╹ ╹┗━╸╹ ╹┗━┛
            */

            #toolbar-menubar menupopup,
            #toolbar-context-menu,
            #toolbar-context-menu menupopup,
            #unified-extensions-context-menu,
            #unified-extensions-context-menu menupopup,
            #placesContext, #placesContext menupopup,
            #downloadsContextMenu, #downloadsContextMenu menupopup,
            #sidebarMenu-popup, #PopupSearchAutoComplete,
            :is(#back-button, #forward-button) menupopup,
            #permission-popup-menulist menupopup,
            #contentAreaContextMenu[showservicesmenu="true"],
            #contentAreaContextMenu[showservicesmenu="true"] menupopup {
              --panel-background: var(--arrowpanel-background) !important;
              --panel-border-color: var(--toolbar-bgcolor) !important;
              --toolbar-field-focus-background-color: var(--toolbarbutton-icon-fill) !important;
              --panel-color: var(--toolbarbutton-icon-fill) !important;

              menu:where([_moz-menuactive="true"]:not([disabled="true"])), 
              menuitem:where([_moz-menuactive="true"]:not([disabled="true"])) {
                background-color: var(--panel-item-hover-bgcolor) !important;
                color: var(--toolbarbutton-icon-fill) !important;
              }
              
              menu:where([_moz-menuactive="true"][disabled="true"]), 
              menuitem:where([_moz-menuactive="true"][disabled="true"]) {
                background-color: transparent !important;
              } 
            }

            /*
            ┏┳┓╻┏┓╻╻┏┳┓┏━┓╻
            ┃┃┃┃┃┗┫┃┃┃┃┣━┫┃
            ╹ ╹╹╹ ╹╹╹ ╹╹ ╹┗━╸
            ┏━╸╻ ╻╺┳╸┏━╸┏┓╻┏━┓╻┏━┓┏┓╻┏━┓
            ┣╸ ┏╋┛ ┃ ┣╸ ┃┗┫┗━┓┃┃ ┃┃┗┫┗━┓
            ┗━╸╹ ╹ ╹ ┗━╸╹ ╹┗━┛╹┗━┛╹ ╹┗━┛
            ┏┳┓┏━╸┏┓╻╻ ╻
            ┃┃┃┣╸ ┃┗┫┃ ┃
            ╹ ╹┗━╸╹ ╹┗━┛
             */

            #unified-extensions-view{
                --uei-icon-size: 24px;
                --extensions-in-row: 4;

                width: 100% !important;
                :is(
                  toolbarseparator,
                  .unified-extensions-item-menu-button.subviewbutton,
                  .unified-extensions-item-action-button .unified-extensions-item-contents
                ) {display: none !important;}

                :is(
                  #overflowed-extensions-list,
                  #unified-extensions-area,
                  .unified-extensions-list 
                ){
                  display: grid !important;
                  grid-template-columns: repeat(var(--extensions-in-row),auto);
                  justify-items: center !important;
                  align-items: center !important;
                }
                
                .unified-extensions-item-action-button {padding-right: 3px !important;}
            }

            /*
            ┏━╸┏━┓┏┓╻╺┳╸┏━┓
            ┣╸ ┃ ┃┃┗┫ ┃ ┗━┓
            ╹  ┗━┛╹ ╹ ╹ ┗━┛
            */

            * {
              font-family: monospace !important;
              font-size: 16px !important;
            }

            /*
            ╻ ╻╻╺┳┓╺┳┓┏━╸┏┓╻
            ┣━┫┃ ┃┃ ┃┃┣╸ ┃┗┫
            ╹ ╹╹╺┻┛╺┻┛┗━╸╹ ╹
            ┏┓╻┏━┓╻ ╻┏┓ ┏━┓┏━┓
            ┃┗┫┣━┫┃┏┛┣┻┓┣━┫┣┳┛
            ╹ ╹╹ ╹┗┛ ┗━┛╹ ╹╹┗╸
            */

            #nav-bar:not([customizing]) {
              opacity: 0;
              min-height: 10px;
              max-height: 10px;
              transition: max-height 1s linear 3s, opacity 600ms ease 3s !important;
            }

            #nav-bar:hover,
            #nav-bar:focus-within {
              opacity: 1;
              min-height: 10px;
              max-height: 50px; 
              transition-duration: 200ms !important;
              transition-delay: 0s, 200ms !important;
            }

            #urlbar:focus-within {
              height: 100% !important;
            }

            .urlbar-input-container {
                height: 105% !important;
            }

            .urlbarView {
                background: var(--arrowpanel-background) !important;
                border-radius: 5px;
            }

            /* 
            ┏━┓┏━╸┏┳┓┏━┓╻ ╻╻┏┓╻┏━╸
            ┣┳┛┣╸ ┃┃┃┃ ┃┃┏┛┃┃┗┫┃╺┓
            ╹┗╸┗━╸╹ ╹┗━┛┗┛ ╹╹ ╹┗━┛
            ┏━╸┏━┓┏┳┓┏━┓┏━┓┏┓╻┏━╸┏┓╻╺┳╸┏━┓
            ┃  ┃ ┃┃┃┃┣━┛┃ ┃┃┗┫┣╸ ┃┗┫ ┃ ┗━┓
            ┗━╸┗━┛╹ ╹╹  ┗━┛╹ ╹┗━╸╹ ╹ ╹ ┗━┛
            */

            /* Tabs elements  */
            #TabsToolbar { display: none !important; }

            #TabsToolbar .titlebar-spacer {
                display: none !important;
            }

            /* Titlebar Window Control Buttons */
            .titlebar-buttonbox-container{ display:none }

            /* Url Bar  */
            #urlbar-input-container {
              border: 1px solid rgba(0, 0, 0, 0) !important;
            }

            #urlbar-container {
              margin: 0 !important;
              padding-block: 2px !important;
              min-height: var(--urlbar-height) !important;
            }

            #urlbar {
              top: 0 !important;
            }

            #urlbar[focused='true'] > #urlbar-background {
              box-shadow: none !important;
            }

            #navigator-toolbox {
              border: none !important;
            }

            /* Bookmarks bar  */
            .bookmark-item .toolbarbutton-icon {
              display: none;
            }
            toolbarbutton.bookmark-item:not(.subviewbutton) {
              min-width: 1.6em;
            }

            /* Toolbar  */
            #tracking-protection-icon-container,
            #urlbar-zoom-button,
            #star-button-box,
            #pageActionButton,
            #pageActionSeparator,
            #tabs-newtab-button,
            #back-button,
            #forward-button,
            .tab-secondary-label {
              display: none !important;
            }

            /* Disable elements  */
            #context-pocket,
            #context-sendpagetodevice,
            #context-selectall,
            #context-inspect-a11y,
            #context-sendlinktodevice,
            #context-openlinkinusercontext-menu,
            #context-savelink,
            #context-savelinktopocket,
            #context-sendlinktodevice,
            #context-sendimage,
            #context-print-selection {
              display: none !important;
            }

            #context_bookmarkTab,
            #context_moveTabOptions,
            #context_sendTabToDevice,
            #context_reopenInContainer,
            #context_selectAllTabs,
            #context_closeTabOptions {
              display: none !important;
            }
          '';

        userContent = # css
          ''
            					/*
            ┏━╸┏━┓┏┓╻╺┳╸┏━┓
            ┣╸ ┃ ┃┃┗┫ ┃ ┗━┓
            ╹  ┗━┛╹ ╹ ╹ ┗━┛
            */
            :root {
              --main-font: monospace;
            }

            /*
            ┏━┓┏━╸┏━┓┏━┓╻  ╻  ┏┓ ┏━┓┏━┓
            ┗━┓┃  ┣┳┛┃ ┃┃  ┃  ┣┻┓┣━┫┣┳┛
            ┗━┛┗━╸╹┗╸┗━┛┗━╸┗━╸┗━┛╹ ╹╹┗╸
            ╻ ╻╻╺┳┓╺┳┓┏━╸┏┓╻
            ┣━┫┃ ┃┃ ┃┃┣╸ ┃┗┫
            ╹ ╹╹╺┻┛╺┻┛┗━╸╹ ╹
            */

            :root {
              scrollbar-width: none !important;
            }

            @-moz-document url(about:privatebrowsing) {
              :root {
                scrollbar-width: none !important;
              }
            }

            /*
            ╻ ╻┏━┓┏┳┓┏━╸┏━┓┏━┓┏━╸┏━╸
            ┣━┫┃ ┃┃┃┃┣╸ ┣━┛┣━┫┃╺┓┣╸
            ╹ ╹┗━┛╹ ╹┗━╸╹  ╹ ╹┗━┛┗━╸
            */

            @-moz-document url("about:home"), url("about:newtab"){
                .search-wrapper,
                .top-site-outer .title{
                    font-family: var(--main-font) !important;
                }

                .top-site-outer .title{
                    font-size: 1rem !important;
                }

                .top-site-outer .top-site-inner > a {
                    padding: 10px 10px 4px !important;
                }

                .search-handoff-button, .search-wrapper input {
                    background: #d8d8d81f !important;
                    border-radius: 5px !important;
                }

                #newtab-search-text::placeholder {
                    opacity: 0 !important;
                }
                :root[lwt-newtab-brighttext]{
                        --newtab-primary-action-background: transparent !important;
                }

                .search-wrapper .search-button,
                .search-wrapper .logo-and-wordmark .logo,
                .fake-textbox,
                .top-site-outer .tile,
                .icon.icon-pin-small {
                    display: none !important;
                }
            }
          '';
      };
    };
  };
}
