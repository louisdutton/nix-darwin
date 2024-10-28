{
  inputs,
  pkgs,
  ...
}:
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
        ];

        # about:config
        settings = {
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

          # custom theme compat
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
          "layers.acceleration.force-enabled" = true;
          "gfx.webrender.all" = true;

          # font
          "font.default.x-western" = "monospace";
          "font.name.monospace.x-western" = "JetBrainsMono Nerd Font";

          # "browser.uiCustomization.state" = # json
        };

        userChrome = # css
          ''
            :root {
            	--background-color-box: #374247 !important;
            	
            	--toolbar-field-background-color: transparent !important;
            	--toolbar-field-focus-background-color: #374247 !important;
            	--toolbar-field-focus-color: #d3c6aa !important;
            	--toolbar-bgcolor: #2f383e !important;
            	--toolbar-color: #d3c6aa !important;
            	--tab-selected-bgcolor: #a7c080 !important;
            	--tab-selected-textcolor: #2b3339 !important;
            	--tab-bgcolor: #323c41 !important;
            	
            	--link-color: #a7c080 !important;
            	--color-accent-primary: #a7c080 !important;
            	
            	/* text */
            	--text-color: #d3c6aa !important;
            		
            	/* sidebar */
              --content-area-shadow: none !important;
              --sidebar-border-color: none !important;
              --sidebar-background-color: #374247 !important;
              --sidebar-text-color: #d3c6aa !important;
            	
            	/* panels */
            	--arrowpanel-background: #374247 !important;
            	--arrowpanel-color: #d3c6aa !important;
            	
            	/* url */
              /*--urlbarView-action-button-background-color: light-dark(white, #1c1b22);*/
            	/*--urlbarView-action-button-hover-color: light-dark(#5b5b66, #fbfbfe);*/
            	/*--urlbarView-action-button-selected-color: light-dark(#1c1b22, light-dark(white, #1c1b22));*/
            	/*--urlbarView-action-color: LinkText;*/
            	/*--urlbarView-action-slide-in-distance: 200px;*/
            	/*--urlbarView-favicon-margin-end: calc(calc((max(32px, 1.4em) - 2px - 2px - 16px ) / 2) + 4px + ((28px - 16px) / 2));*/
            	/*--urlbarView-favicon-margin-start: calc((28px - 16px) / 2);*/
            	/*--urlbarView-favicon-width: 16px;*/
            	--urlbarView-highlight-background: #a7c080 !important;
            	--urlbarView-highlight-color: #2b3339 !important;
            	/*--urlbarView-hover-background: color-mix(in srgb, currentColor 17%, transparent);*/
            	/*--urlbarView-icon-margin-end: calc(calc((max(32px, 1.4em) - 2px - 2px - 16px ) / 2) + 4px);*/
            	/*--urlbarView-icon-margin-start: 0px;*/
            	/*--urlbarView-item-block-padding: 6px;*/
            	/*--urlbarView-item-inline-padding: calc((max(32px, 1.4em) - 2px - 2px - 16px ) / 2);*/
            	/*--urlbarView-labeled-row-label-top: calc(-1.27em - 2px);*/
            	/*--urlbarView-labeled-row-margin-top: calc(1.46em + 4px);*/
            	/*--urlbarView-labeled-tip-margin-top-extra: 8px;*/
            	/*--urlbarView-result-button-background-opacity: 60%;*/
            	/*--urlbarView-result-button-hover-background-color: color-mix(in srgb, FieldText 60%, transparent);*/
            	/*--urlbarView-result-button-hover-color: Field;*/
            	/*--urlbarView-result-button-selected-background-color: color-mix(in srgb, Field 60%, transparent);*/
            	/*--urlbarView-result-button-selected-color: FieldText;*/
            	/*--urlbarView-result-button-size: 24px;*/
            	--urlbarView-results-padding: 0 !important;
            	/*--urlbarView-rich-suggestion-default-icon-size: 28px;*/
            	--urlbarView-row-gutter: 0 !important;
            	/*--urlbarView-secondary-text-color: color-mix(in srgb, currentColor 73%, transparent);*/
            	/*--urlbarView-separator-color: color-mix(in srgb, currentColor 14%, transparent);*/
            	/*--urlbarView-small-font-size: 0.85em;*/


            }

            .urlbarView-Row { border-radius: 0 !important; }
            .urlbarView-url { margin-top: 0px !important; }
            .urlbarView-button-menu
            {
            	display: none !important;
            	user-select: none;
            }

            /* sidebar */
            /* ignore horizontal options */
            moz-radio-group[name="tabDirection"] {
            	display: none !important;
            }

            #tabbrowser-tabs {
            	padding-top: 10px !important;
            };

            .tab-background {
            	box-shadow: none !important;
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
            		--uei-icon-size: 20px;

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
            			display: flex !important;
            			flex-direction: row;
            			gap: 5px;
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
            	font-size: 13px !important;
            }

            /*
            ╻ ╻╻╺┳┓╺┳┓┏━╸┏┓╻
            ┣━┫┃ ┃┃ ┃┃┣╸ ┃┗┫
            ╹ ╹╹╺┻┛╺┻┛┗━╸╹ ╹
            ┏┓╻┏━┓╻ ╻┏┓ ┏━┓┏━┓
            ┃┗┫┣━┫┃┏┛┣┻┓┣━┫┣┳┛
            ╹ ╹╹ ╹┗┛ ┗━┛╹ ╹╹┗╸
            */

            #nav-bar {
            	height: 40px;
            }

            #nav-bar:hover,
            #nav-bar:focus-within {
            	
            }

            #urlbar:focus-within {
            	height: 100% !important;
            }

            #urlbar-background {
            	animation: none !important;
            	box-shadow: none !important;
            	border: none !important;
            }

            .urlbar-input-container {
            		height: 40px !important;
            }

            .urlbarView {
            		background: var(--arrowpanel-background) !important;
            		border-radius: 10px;
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

            #new-tab-button,
            #PanelUI-menu-button,
            #unified-extensions-button {
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
