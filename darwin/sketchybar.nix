{ ... }:
{
  services.sketchybar = {
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
}
