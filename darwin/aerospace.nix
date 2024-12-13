{
  pkgs,
  keymap,
  lib,
  ...
}:
let
  padding = 10;
in
{
  # https://nikitabobko.github.io/AeroSpace
  services.aerospace = {
    enable = true;
    settings = {
      after-startup-command = [ ];

      exec-on-workspace-change = [
        (lib.getExe pkgs.zsh)
        "-c"
        "${lib.getExe pkgs.sketchybar} --trigger aerospace_workspace_change AEROSPACE_FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE AEROSPACE_PREV_WORKSPACE=$AEROSPACE_PREV_WORKSPACE"
      ];

      # normalisation
      enable-normalization-flatten-containers = true;
      enable-normalization-opposite-orientation-for-nested-containers = true;

      # layouts
      default-root-container-layout = "tiles";
      default-root-container-orientation = "auto";

      # mouse
      on-focused-monitor-changed = [ "move-mouse monitor-lazy-center" ];

      # gaps
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

      # keybinds
      key-mapping.preset = "qwerty";
      mode = {
        main.binding = with keymap; {
          # misc
          "${mod}-r" = "reload-config";

          # apps
          "${mod}-enter" = "exec-and-forget open -a wezterm";

          # layout
          "${mod}-slash" = "layout tiles horizontal vertical";
          "${mod}-comma" = "layout accordion horizontal vertical";

          # windows
          "${mod}-${left}" = "focus left --boundaries all-monitors-outer-frame";
          "${mod}-${down}" = "focus down --boundaries all-monitors-outer-frame";
          "${mod}-${up}" = "focus up --boundaries all-monitors-outer-frame";
          "${mod}-${right}" = "focus right --boundaries all-monitors-outer-frame";

          "${move}-${left}" = "move left";
          "${move}-${down}" = "move down";
          "${move}-${up}" = "move up";
          "${move}-${right}" = "move right";

          "${move}-minus" = "resize smart -50";
          "${move}-equal" = "resize smart +50";

          "${mod}-f" = "fullscreen";
          "${mod}-q" = "close --quit-if-last-window";

          # workspaces
          "${mod}-1" = "workspace 1";
          "${mod}-2" = "workspace 2";
          "${mod}-3" = "workspace 3";
          "${mod}-tab" = "workspace-back-and-forth";

          "${move}-1" = "move-node-to-workspace 1";
          "${move}-2" = "move-node-to-workspace 2";
          "${move}-3" = "move-node-to-workspace 3";
          "${move}-tab" = "move-workspace-to-monitor --wrap-around next";
        };
      };

      # autocmds FIXME
      # on-window-detected =
      #   let
      #     bind = id: space: {
      #       "if".app-id = id;
      #       run = "move-node-to-workspace ${space}";
      #     };
      #   in
      #   [
      #     (bind "com.github.wez.wezterm" "1")
      #     (bind "com.tinyspeck.slackmacgap" "3")
      #   ];
    };
  };
}
