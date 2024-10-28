{ pkgs, user, ... }:
let
  toml = pkgs.formats.toml { };
in
{
  environment.systemPackages = with pkgs; [
    aerospace
  ];

  home-manager.users.${user.name}.home.file.".config/aerospace/aerospace.toml".source =
    toml.generate ".aerospace.toml"
      {
        after-login-command = [ ];
        after-startup-command = [ ];
        start-at-login = true;
        # exec = {
        #   inherit-env-vars = true;
        #   env-vars = {
        #     PATH = "/Users/louis/.nix-profile/bin /etc/profiles/per-user/louis/bin /run/current-system/sw/bin /nix/var/nix/profiles/default/bin /usr/local/bin /usr/bin /usr/sbin /bin /sbin /Users/louis/.zsh/plugins/zsh-system-clipboard";
        #   };
        # };

        exec-on-workspace-change = [
          "/bin/zsh"
          "-c"
          "sketchybar --trigger aerospace_workspace_change AEROSPACE_FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE AEROSPACE_PREV_WORKSPACE=$AEROSPACE_PREV_WORKSPACE"
        ];

        # Normalizations. See: https://nikitabobko.github.io/AeroSpace/guide#normalization
        enable-normalization-flatten-containers = true;
        enable-normalization-opposite-orientation-for-nested-containers = true;

        # See: https://nikitabobko.github.io/AeroSpace/guide#layouts
        # The "accordion-padding" specifies the size of accordion padding
        # You can set 0 to disable the padding feature
        accordion-padding = 30;

        # Possible values: tiles|accordion
        default-root-container-layout = "tiles";

        # Possible values: horizontal|vertical|auto
        # "auto" means: wide monitor (anything wider than high) gets horizontal orientation
        #               tall monitor (anything higher than wide) gets vertical orientation
        default-root-container-orientation = "auto";

        # Mouse follows focus when focused monitor changes
        # Drop it from your config if you don"t like this behavior
        # See https://nikitabobko.github.io/AeroSpace/guide#on-focus-changed-callbacks
        # See https://nikitabobko.github.io/AeroSpace/commands#move-mouse
        # Fallback value (if you omit the key): on-focused-monitor-changed = []
        on-focused-monitor-changed = [ "move-mouse monitor-lazy-center" ];

        # Possible values: (qwerty|dvorak)
        # See https://nikitabobko.github.io/AeroSpace/guide#key-mapping
        key-mapping = {
          preset = "qwerty";
        };

        # Gaps between windows (inner-*) and between monitor edges (outer-*).
        # Possible values:
        # - Constant:     gaps.outer.top = 8
        # - Per monitor:  gaps.outer.top = [{ monitor.main = 16 } { monitor."some-pattern" = 32 } 24]
        #                 In this example 24 is a default value when there is no match.
        #                 Monitor pattern is the same as for "workspace-to-monitor-force-assignment".
        #                 See: https://nikitabobko.github.io/AeroSpace/guide#assign-workspaces-to-monitors
        gaps = {
          inner = {
            horizontal = 10;
            vertical = 10;
          };
          outer = {
            left = 10;
            bottom = 10;
            top = 20;
            right = 10;
          };
        };

        # See: https://nikitabobko.github.io/AeroSpace/guide#binding-modes
        mode = {
          main.binding = {
            # All possible keys:
            # - Letters.        a b c ... z
            # - Numbers.        0 1 2 ... 9
            # - Keypad numbers. keypad0 keypad1 keypad2 ... keypad9
            # - F-keys.         f1 f2 ... f20
            # - Special keys.   minus equal period comma slash backslash quote semicolon backtick
            #                   leftSquareBracket rightSquareBracket space enter esc backspace tab
            # - Keypad special. keypadClear keypadDecimalMark keypadDivide keypadEnter keypadEqual
            #                   keypadMinus keypadMultiply keypadPlus
            # - Arrows.         left down up right

            # All possible modifiers: cmd alt ctrl shift

            # All possible commands: https://nikitabobko.github.io/AeroSpace/commands
            cmd-n = "exec-and-forget open -n -a Alacritty";
            cmd-b = "exec-and-forget open -n -a 'Firefox Developer Edition'";
            cmd-space = "exec-and-forget zsh -c choose-app";

            cmd-r = "reload-config";
            cmd-f = "fullscreen";

            # See: https://nikitabobko.github.io/AeroSpace/commands#layout
            cmd-slash = "layout tiles horizontal vertical";
            cmd-comma = "layout accordion horizontal vertical";

            # See: https://nikitabobko.github.io/AeroSpace/commands#focus
            cmd-h = "focus left --boundaries all-monitors-outer-frame";
            cmd-j = "focus down --boundaries all-monitors-outer-frame";
            cmd-k = "focus up --boundaries all-monitors-outer-frame";
            cmd-l = "focus right --boundaries all-monitors-outer-frame";

            # See: https://nikitabobko.github.io/AeroSpace/commands#move
            cmd-shift-h = "move left";
            cmd-shift-j = "move down";
            cmd-shift-k = "move up";
            cmd-shift-l = "move right";

            # See: https://nikitabobko.github.io/AeroSpace/commands#resize
            cmd-shift-minus = "resize smart -50";
            cmd-shift-equal = "resize smart +50";

            # See: https://nikitabobko.github.io/AeroSpace/commands#workspace
            cmd-1 = "workspace 1";
            cmd-2 = "workspace 2";
            cmd-3 = "workspace 3";
            cmd-4 = "workspace 4";
            cmd-5 = "workspace 5";
            cmd-6 = "workspace 6";
            cmd-7 = "workspace 7";
            cmd-8 = "workspace 8";
            cmd-9 = "workspace 9";

            # See: https://nikitabobko.github.io/AeroSpace/commands#move-node-to-workspace
            cmd-shift-1 = "move-node-to-workspace 1";
            cmd-shift-2 = "move-node-to-workspace 2";
            cmd-shift-3 = "move-node-to-workspace 3";
            cmd-shift-4 = "move-node-to-workspace 4";
            cmd-shift-5 = "move-node-to-workspace 5";
            cmd-shift-6 = "move-node-to-workspace 6";
            cmd-shift-7 = "move-node-to-workspace 7";
            cmd-shift-8 = "move-node-to-workspace 8";
            cmd-shift-9 = "move-node-to-workspace 9";

            # See: https://nikitabobko.github.io/AeroSpace/commands#workspace-back-and-forth
            cmd-tab = "workspace-back-and-forth";
            # See: https://nikitabobko.github.io/AeroSpace/commands#move-workspace-to-monitor
            cmd-shift-tab = "move-workspace-to-monitor --wrap-around next";

            # See: https://nikitabobko.github.io/AeroSpace/commands#mode
            cmd-shift-semicolon = "mode service";
          };

          # "service" binding mode declaration.
          # See: https://nikitabobko.github.io/AeroSpace/guide#binding-modes
          service.binding = {
            esc = [
              "reload-config"
              "mode main"
            ];
            r = [
              "flatten-workspace-tree"
              "mode main"
            ]; # reset layout
            f = [
              "layout floating tiling"
              "mode main"
            ]; # Toggle between floating and tiling layout
            backspace = [
              "close-all-windows-but-current"
              "mode main"
            ];

            # sticky is not yet supported https://github.com/nikitabobko/AeroSpace/issues/2
            #s = ["layout sticky tiling" "mode main"]

            cmd-shift-h = [
              "join-with left"
              "mode main"
            ];
            cmd-shift-j = [
              "join-with down"
              "mode main"
            ];
            cmd-shift-k = [
              "join-with up"
              "mode main"
            ];
            cmd-shift-l = [
              "join-with right"
              "mode main"
            ];
          };
        };

      };
}
