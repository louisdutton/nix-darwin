{ user, ... }:
let
  font = "JetBrainsMono Nerd Font";
  configDir = ".config/sketchybar";
  pluginDir = "${configDir}/plugins";

  toArg = name: value: "--${name}=${toString value}";
  mkArgs = opts: builtins.concatStringsSep " " (builtins.attrValues (builtins.mapAttrs toArg opts));
  mkCmd = cmd: opts: "sketchybar ${cmd} ${mkArgs opts}";

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
      height = 48;
      position = "top";
      # y_offset = 10
      # blur_radius=30
      # sticky=off
      # padding_left=10
      # padding_right=10
      # color=0x7f000000
    };

    default = {
      padding_left = 5;
      padding_right = 5;
      "icon.font" = "\"${font}:Bold:14.0\"";
      "label.font" = "\"${font}:Bold:14.0\"";
      "icon.color" = "0xffffffff";
      "label.color" = "0xffffffff";
      "icon.padding_left" = 4;
      "icon.padding_right" = 4;
      "label.padding_left" = 4;
      "label.padding_right" = 4;
    };
  };

  spaceIcon = space: {
    space = "${space}";
    icon = "${space}";
    "icon.padding_left" = 8;
    "icon.padding_right" = 8;
    "background.color" = "0x40ffffff";
    "background.corner_radius" = 5;
    "background.height" = 25;
    "label.drawing" = "off";
    script = "~/${pluginDir}/space.sh";
    click_script = "\"yabai -m space --focus $sid\"";
  };

  plugins = {
    clock = ''
      sketchybar --set "$NAME" label="$(date '+%d/%m %H:%M')"
    '';

    battery = ''
      PERCENTAGE="$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)"
      CHARGING="$(pmset -g batt | grep 'AC Power')"

      if [ "$PERCENTAGE" = "" ]; then
        exit 0
      fi

      case "''${PERCENTAGE}" in
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
in
{
  services.sketchybar.enable = true;

  # https://felixkratz.github.io/SketchyBar/config
  home-manager.users.${user.name}.home.file = builtins.listToAttrs [
    (mkConfig (
      builtins.concatStringsSep "\n" [
        (mkCmd "--bar" sketchybar.bar)
        (mkCmd "--default" sketchybar.default)
        # (map (i: mkCmd "add space space.${i} left --set space.${i}" (spaceIcon i)) [
        #   "1"
        #   "2"
        #   "3"
        # ])
        ''
          ##### Adding Left Items #####

          sketchybar --add item chevron left \
          					 --set chevron icon= label.drawing=off \
          					 --add item front_app left \
          					 --set front_app icon.drawing=off script="~/${pluginDir}/front_app.sh" \
          					 --subscribe front_app front_app_switched

          ##### Adding Right Items #####

          sketchybar --add item clock right \
          					 --set clock update_freq=10 icon=  script="~/${pluginDir}/clock.sh" \
          					 --add item volume right \
          					 --set volume script="~/${pluginDir}/volume.sh" \
          					 --subscribe volume volume_change \
          					 --add item battery right \
          					 --set battery update_freq=120 script="~/${pluginDir}/battery.sh" \
          					 --subscribe battery system_woke power_source_change
        ''
        ''
          sketchybar --hotload true
          sketchybar --update
        ''
      ]
    ))
  ];
  # ++ builtins.attrValues (builtins.mapAttrs mkPlugin plugins);
}
