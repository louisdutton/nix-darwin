{
  pkgs,
  user,
  keymap,
  lib,
  ...
}:
let
  toml = pkgs.formats.toml { };
  padding = 10;
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

        exec-on-workspace-change = [
          (lib.getExe pkgs.zsh)
          "-c"
          "${lib.getExe pkgs.sketchybar} --trigger aerospace_workspace_change AEROSPACE_FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE AEROSPACE_PREV_WORKSPACE=$AEROSPACE_PREV_WORKSPACE"
        ];

        # https://nikitabobko.github.io/AeroSpace/guide#normalization
        enable-normalization-flatten-containers = true;
        enable-normalization-opposite-orientation-for-nested-containers = true;

        # https://nikitabobko.github.io/AeroSpace/guide#layouts
        default-root-container-layout = "tiles";
        default-root-container-orientation = "auto";

        # https://nikitabobko.github.io/AeroSpace/guide#on-focus-changed-callbacks
        # https://nikitabobko.github.io/AeroSpace/commands#move-mouse
        on-focused-monitor-changed = [ "move-mouse monitor-lazy-center" ];

        # https://nikitabobko.github.io/AeroSpace/guide#assign-workspaces-to-monitors
        accordion-padding = padding;
        gaps = {
          inner = {
            horizontal = padding;
            vertical = padding;
          };
          outer = {
            left = padding;
            bottom = padding;
            right = padding;
            top = [
              { monitor."built-in" = 20; }
              50 # any external monitor
            ];
          };
        };

        # See https://nikitabobko.github.io/AeroSpace/guide#key-mapping
        key-mapping.preset = "qwerty";

        # See: https://nikitabobko.github.io/AeroSpace/guide#binding-modes
        mode = {
          # All possible commands: https://nikitabobko.github.io/AeroSpace/commands
          main.binding = with keymap; {
            # open terminal
            "${mod}-enter" = "exec-and-forget open -a wezterm";

            "${mod}-q" = "close --quit-if-last-window";
            "${mod}-r" = "reload-config";
            "${mod}-f" = "fullscreen";

            # See: https://nikitabobko.github.io/AeroSpace/commands#layout
            "${mod}-slash" = "layout tiles horizontal vertical";
            "${mod}-comma" = "layout accordion horizontal vertical";

            # See: https://nikitabobko.github.io/AeroSpace/commands#focus
            "${mod}-${left}" = "focus left --boundaries all-monitors-outer-frame";
            "${mod}-${down}" = "focus down --boundaries all-monitors-outer-frame";
            "${mod}-${up}" = "focus up --boundaries all-monitors-outer-frame";
            "${mod}-${right}" = "focus right --boundaries all-monitors-outer-frame";

            # See: https://nikitabobko.github.io/AeroSpace/commands#move
            "${move}-${left}" = "move left";
            "${move}-${down}" = "move down";
            "${move}-${up}" = "move up";
            "${move}-${right}" = "move right";

            # See: https://nikitabobko.github.io/AeroSpace/commands#resize
            "${move}-minus" = "resize smart -50";
            "${move}-equal" = "resize smart +50";

            "${mod}-tab" = "workspace-back-and-forth"; # https://nikitabobko.github.io/AeroSpace/commands#workspace-back-and-forth
            "${move}-tab" = "move-workspace-to-monitor --wrap-around next"; # https://nikitabobko.github.io/AeroSpace/commands#move-workspace-to-monitor

            # https://nikitabobko.github.io/AeroSpace/commands#workspace
            "${mod}-1" = "workspace 1";
            "${mod}-2" = "workspace 2";
            "${mod}-3" = "workspace 3";

            "${move}-1" = "move-node-to-workspace 1";
            "${move}-2" = "move-node-to-workspace 2";
            "${move}-3" = "move-node-to-workspace 3";

            # See: https://nikitabobko.github.io/AeroSpace/commands#mode
            "${mod}-shift-semicolon" = "mode service";
          };
        };

        # autocmds
        on-window-detected =
          let
            bind = id: space: {
              "if".app-id = id;
              run = "move-node-to-workspace ${space}";
            };
          in
          [
            (bind "com.github.wez.wezterm" "1")
            (bind "com.tinyspeck.slackmacgap" "3")
          ];
      };
}
