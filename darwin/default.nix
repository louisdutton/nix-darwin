{
  pkgs,
  config,
  user,
  ...
}:
{
  nix = {
    channel.enable = false;
  };

  # homedir fix
  users.users.${user.name}.home = "/Users/louis";

  environment = {
    systemPackages = with pkgs; [
      raycast
      alacritty
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
      };

      NSGlobalDomain = {
        AppleInterfaceStyle = "Dark";
        AppleShowAllFiles = true;

        # keyboard
        AppleKeyboardUIMode = 3; # full keyboard control
        ApplePressAndHoldEnabled = false;
        InitialKeyRepeat = 15; # 120, 90, 60, 30, 12, 6, 2
        KeyRepeat = 2; # 120, 90, 60, 30, 12, 6, 2
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticDashSubstitutionEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticQuoteSubstitutionEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;

        NSNavPanelExpandedStateForSaveMode = true;
        NSNavPanelExpandedStateForSaveMode2 = true;

        NSAutomaticWindowAnimationsEnabled = false;
        _HIHideMenuBar = true;
      };
    };

    # check `man configuration.nix` before changing
    stateVersion = 5;
  };

  services = {
    # Auto upgrade nix package and the daemon service.
    nix-daemon.enable = true;

    sketchybar = {
      enable = true;
      config =
        let
          clock = ''
            sketchybar --set $NAME label="$(date '+%a %b %-d %-H:%M')"
          '';
          currentSpace = ''
            update_space() {
                SPACE_ID=$(echo "$INFO" | jq -r '."display-1"')

                case $SPACE_ID in
                1)
                    ICON=󰅶
                    ICON_PADDING_LEFT=7
                    ICON_PADDING_RIGHT=7
                    ;;
                *)
                    ICON=$SPACE_ID
                    ICON_PADDING_LEFT=9
                    ICON_PADDING_RIGHT=10
                    ;;
                esac

                sketchybar --set $NAME \
                    icon=$ICON \
                    icon.padding_left=$ICON_PADDING_LEFT \
                    icon.padding_right=$ICON_PADDING_RIGHT
            }

            case "$SENDER" in
            "mouse.clicked")
                # Reload sketchybar
                sketchybar --remove '/.*/'
                source $HOME/.config/sketchybar/sketchybarrc
                ;;
            *)
                update_space
                ;;
            esac
          '';
        in
        ''
          FONT_FACE="JetBrainsMono Nerd Font"

          sketchybar --bar \
              height=32 \
              color=0x66494d64 \
              margin=16 \
              sticky=on \
              padding_left=16 \
              padding_right=16 \
              notch_width=188 \
              display=main

          sketchybar --default \
              background.height=32 \
              icon.color=0xff24273a \
              icon.font="$FONT_FACE:Medium:20.0" \
              icon.padding_left=5 \
              icon.padding_right=5 \
              label.color=0xff24273a \
              label.font="$FONT_FACE:Bold:14.0" \
              label.y_offset=1 \
              label.padding_left=0 \
              label.padding_right=5

          sketchybar --add item current_space left \
              --set current_space \
              background.color=0xfff5a97f \
              label.drawing=off \
              script="${currentSpace}" \
              --subscribe current_space space_change mouse.clicked

          sketchybar --add item clock right \
              --set clock \
              icon=󰃰 \
              background.color=0xffed8796 \
              update_freq=10 \
              script="${clock}"

          ##### Finalizing Setup #####
          sketchybar --update
          sketchybar --trigger space_change
          		'';
    };

    yabai = {
      enable = true;
      # enableScriptingAddition = true;
      config = {
        layout = "bsp";
        auto_balance = "off";
        window_placement = "second_child";

        top_padding = 16;
        bottom_padding = 16;
        left_padding = 16;
        right_padding = 16;
        window_gap = 16;

        focus_follows_mouse = "autofocus";
        mouse_modifier = "alt";
        mouse_action1 = "move";
        mouser_action2 = "resize";
        mouse_drop_action = "swap";

        window_topmost = "off";
        window_opacity = "off";
        window_shadow = "off";
        split_ratio = 0.5;

        external_bar = "all:45:0";
      };

      extraConfig = ''
        # Notify sketchybar when space changes
        yabai -m signal --add event=window_focused action="sketchybar --trigger window_focus"
        yabai -m signal --add event=window_title_changed action="sketchybar --trigger title_change"

        # Rules for specific apps
        yabai -m rule --add app="^System Settings$" manage=off
        yabai -m rule --add label="Finder" app="^Finder$" title="(Co(py|nnect)|Move|Info|Pref)" manage=off
        yabai -m rule --add label="Safari" app="^Safari$" title="^(General|(Tab|Password|Website|Extension)s|AutoFill|Se(arch|curity)|Privacy|Advance)$" manage=off
        yabai -m rule --add label="System Preferences" app="^System Preferences$" title=".*" manage=off
        yabai -m rule --add label="App Store" app="^App Store$" manage=off
        yabai -m rule --add label="Activity Monitor" app="^Activity Monitor$" manage=off
        yabai -m rule --add label="Calculator" app="^Calculator$" manage=off
        yabai -m rule --add label="Dictionary" app="^Dictionary$" manage=off
        yabai -m rule --add label="Software Update" title="Software Update" manage=off
        yabai -m rule --add label="About This Mac" app="System Information" title="About This Mac" manage=off
      '';
    };
    skhd = {
      enable = true;
      package = pkgs.skhd;
      skhdConfig = ''
        # restart services
        cmd + shift - r : yabai --restart-service && skhd --restart-service

        # arrow keys
        ctrl - h : skhd -k left
        ctrl - j : skhd -k down
        ctrl - k : skhd -k up
        ctrl - l : skhd -k right

        # unique programs
        cmd - n : alacritty
        cmd - space : ${pkgs.raycast}/Applications/Raycast.app/Contents/MacOS/Raycast
        cmd - b : ${pkgs.firefox-devedition-bin}/Applications/Firefox\ Developer\ Edition.app/Contents/MacOS/firefox

        # space navigation
        cmd - 1 : yabai -m space --focus 1
        cmd - 2 : yabai -m space --focus 2
        cmd - 3 : yabai -m space --focus 3

        # window navigation
        cmd - h : yabai -m window --focus west
        cmd - j : yabai -m window --focus south
        cmd - k : yabai -m window --focus north
        cmd - l : yabai -m window --focus east

        # window movement
        cmd + ctrl - h : yabai -m window --swap west
        cmd + ctrl - j : yabai -m window --swap south
        cmd + ctrl - k : yabai -m window --swap north
        cmd + ctrl - l : yabai -m window --swap east

        # window zoom
        cmd - d : yabai -m window --toggle zoom-parent
        cmd - f : yabai -m window --toggle zoom-fullscreen
      '';
    };

    jankyborders = {
      enable = true;
      width = 5.0;
      order = "above";
      active_color = "0xff${config.lib.stylix.colors.base0D}";
      inactive_color = "0xff${config.lib.stylix.colors.base03}";
      hidpi = true;
    };
  };

  # system.userActivationScripts.wallpaper = {
  #   enable = true;
  #   source = ''
  #     osascript -e "tell application \"System Events\" to tell every desktop to set picture to \"${config.lib.stylix.image}\" as POSIX file"
  #   '';
  # };
}
