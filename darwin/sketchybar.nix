{
  user,
  config,
  pkgs,
  ...
}:
let
  font = config.stylix.fonts.monospace.name;
  configDir = ".config/sketchybar";
  pluginDir = "${configDir}/plugins";

  kv = name: value: "${name}=\"${toString value}\"";
  mkArgs = opts: builtins.concatStringsSep " " (builtins.attrValues (builtins.mapAttrs kv opts));
  mkCmd = cmd: opts: "${cmd} ${mkArgs opts}";
  mkAdd =
    type: name: opts: position:
    mkCmd "--add ${type} ${name} ${position} --set ${name}" opts;
  mkItem =
    name: opts: position:
    mkAdd "item" name opts position;
  mkSpace = opts: position: mkAdd "space" "space.${opts.space}" opts position;

  mkFile = name: text: {
    inherit name;
    value = {
      inherit text;
      enable = true;
      executable = true;
    };
  };

  mkPlugin = name: text: mkFile "${pluginDir}/${name}.sh" text;
  mkConfig = text: mkFile "${configDir}/sketchybarrc" text;

  sketchybar = {
    bar = {
      height = 32;
      position = "top";
      # border_color = "0xaa${config.lib.stylix.colors.base03}";
      # border_width = 3.5;
      # border_radius = 10;
      margin = 10;
      y_offset = 10;
      corner_radius = 10;
      padding_left = 0;
      padding_right = 0;
      color = "0x00${config.lib.stylix.colors.base00}";
      font_smoothing = "off";
    };

    default = {
      padding_left = 4;
      padding_right = 4;

      "icon.font" = "${font}:Bold:14.0";
      "icon.color" = "0xff${config.lib.stylix.colors.base05}";
      "icon.padding_left" = 8;

      "label.font" = "${font}:Bold:14.0";
      "label.color" = "0xff${config.lib.stylix.colors.base05}";
      "label.padding_left" = 4;
      "label.padding_right" = 8;

      "background.corner_radius" = 5;
    };

    spaces = map (space: {
      inherit space;
      icon = space;
      "icon.padding_left" = 8;
      "icon.padding_right" = 8;
      "background.color" = "0xff${config.lib.stylix.colors.base02}";
      "background.height" = 25;
      "label.drawing" = "off";
      script = "~/${pluginDir}/space.sh";
      click_script = "aerospace workspace ${space}";
    }) (builtins.genList (x: toString (x + 1)) 9);

    items = {
      right = {
        battery = {
          update_freq = 120;
          script = "~/${pluginDir}/battery.sh";
        };

        volume = {
          script = "~/${pluginDir}/volume.sh";
        };

        clock = {
          update_freq = 10;
          icon = "";
          script = "~/${pluginDir}/clock.sh";
        };

        pomodoro = {
          update_freq = 1;
          icon = "";
          script = "~/${pluginDir}/pomodoro.sh";
          "background.color" = "0xff${config.lib.stylix.colors.base02}";
        };
      };

      left = {
        chevron = {
          icon = "";
          "label.drawing" = "off";
        };

        front_app = {
          "icon.drawing" = "off";
          script = "~/${pluginDir}/front_app.sh";
        };
      };
    };

    subscriptions =
      let
        sub = from: to: { inherit from to; };
      in
      [
        (sub "front_app" [ "front_app_switched" ])
        (sub "volume" [ "volume_change" ])
        (sub "battery" [
          "system_woke"
          "power_source_change"
        ])
      ];

    plugins = {
      clock = ''
        sketchybar --set "$NAME" label="$(date '+%d/%m %H:%M')"
      '';

      pomodoro = ''
        status="$(${pkgs.openpomodoro-cli}/bin/pomodoro status -f '%r')"

        if [ "$status" = "" ]; then
          sketchybar --set "$NAME" drawing="off"
        else
          sketchybar --set "$NAME" drawing="on"
          sketchybar --set "$NAME" label="$status"

          case "$status" in
            [1-9][0-9]:[0-9][0-9]) color="0xff${config.lib.stylix.colors.base0D}"
            ;;
            [5-9]:[0-9][0-9]) color="0xff${config.lib.stylix.colors.base0A}"
            ;;
            *) color="0xff${config.lib.stylix.colors.base08}"
          esac

          sketchybar --set "$NAME" \
            background.color="$color" \
            icon.color="0xff${config.lib.stylix.colors.base00}" \
            label.color="0xff${config.lib.stylix.colors.base00}"
        fi
      '';

      battery = ''
        PERCENTAGE="$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)"
        CHARGING="$(pmset -g batt | grep 'AC Power')"

        if [ "$PERCENTAGE" = "" ]; then
          exit 0
        fi

        case "$PERCENTAGE" in
          9[0-9]|100) ICON=""
          ;;
          [6-8][0-9]) ICON=""
          ;;
          [3-5][0-9]) ICON=""
          ;;
          [1-2][0-9]) ICON=""
          ;;
          *) ICON=""
        esac

        if [[ "$CHARGING" != "" ]]; then
          ICON=""
        fi

        sketchybar --set "$NAME" icon="$ICON" label="''${PERCENTAGE}%"
      '';

      front_app = ''
        if [ "$SENDER" = "front_app_switched" ]; then
          sketchybar --set "$NAME" label="$INFO"
        fi
      '';

      space = ''
        sketchybar --set "$NAME" background.drawing="$SELECTED"
      '';

      volume = ''
        if [ "$SENDER" = "volume_change" ]; then
          VOLUME="$INFO"

          case "$VOLUME" in
            [6-9][0-9]|100) ICON="󰕾"
            ;;
            [3-5][0-9]) ICON="󰖀"
            ;;
            [1-9]|[1-2][0-9]) ICON="󰕿"
            ;;
            *) ICON="󰖁"
          esac

          sketchybar --set "$NAME" icon="$ICON" label="$VOLUME%"
        fi
      '';
    };
  };

in
{
  services.sketchybar.enable = true;

  # https://felixkratz.github.io/SketchyBar/config
  home-manager.users.${user.name}.home.file = builtins.listToAttrs (
    [
      (mkConfig (
        builtins.concatStringsSep " \\\n  " (
          [
            "sketchybar"
            (mkCmd "--bar" sketchybar.bar)
            (mkCmd "--default" sketchybar.default)
          ]
          ++ map (s: mkSpace s "left") sketchybar.spaces
          ++ builtins.attrValues (builtins.mapAttrs (k: v: mkItem k v "left") sketchybar.items.left)
          ++ builtins.attrValues (builtins.mapAttrs (k: v: mkItem k v "right") sketchybar.items.right)
          ++ map (s: "--subscribe ${s.from} ${builtins.concatStringsSep " " s.to}") sketchybar.subscriptions
          ++ [
            "--hotload true"
            "--update"
          ]
        )
      ))
    ]
    ++ builtins.attrValues (builtins.mapAttrs mkPlugin sketchybar.plugins)
  );
}
