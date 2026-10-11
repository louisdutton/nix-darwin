let
  button = name: source: target: {
    inherit name;
    source_event.gamepad.button = source;
    target_events = [target];
  };
  key = name: source: keyboard: button name source {inherit keyboard;};
  stickAxis = stick: name: direction: keyboard: {
    inherit name;
    source_event.gamepad.axis = {
      name = stick;
      inherit direction;
      deadzone = 0.4;
    };
    target_events = [{inherit keyboard;}];
  };
  axis = stickAxis "LeftStick";
  ignore = name: event: {
    inherit name;
    source_event.gamepad = event;
    target_events = [];
  };
in {
  useBundledDeviceConfigs = false;
  defaultProfile = "kodi";
  devices."10-theatre-pro" = {
    version = 1;
    kind = "CompositeDevice";
    name = "Theatre Pro Controller";
    matches = [];
    maximum_sources = 1;
    options = {
      auto_manage = true;
      persist = true;
    };
    source_devices = [
      {
        group = "gamepad";
        evdev = {
          vendor_id = "057e";
          product_id = "2009";
          name = "*Pro Controller";
          handler = "event*";
        };
      }
    ];
    target_devices = ["xb360" "keyboard"];
  };
  profiles.kodi = {
    version = 1;
    kind = "DeviceProfile";
    name = "Theatre Kodi";
    description = "Keyboard navigation without leaking gamepad events to background games.";
    mapping = [
      (key "Power" "Guide" "KeyF7")
      (key "Nintendo A selects" "East" "KeyEnter")
      (key "Nintendo B goes back" "South" "KeyBackspace")
      (key "Nintendo X context menu" "North" "KeyC")
      (key "Nintendo Y play pause" "West" "KeySpace")
      (key "Settings" "Start" "KeyF6")
      (ignore "Unused minus button" {button = "Select";})
      (key "Up" "DPadUp" "KeyUp")
      (key "Down" "DPadDown" "KeyDown")
      (key "Left" "DPadLeft" "KeyLeft")
      (key "Right" "DPadRight" "KeyRight")
      (axis "Stick Up" "up" "KeyUp")
      (axis "Stick Down" "down" "KeyDown")
      (axis "Stick Left" "left" "KeyLeft")
      (axis "Stick Right" "right" "KeyRight")
      (key "Left page" "LeftBumper" "KeyPageUp")
      (key "Right page" "RightBumper" "KeyPageDown")
      (ignore "Ignore other gamepad buttons" {button = "LeftStick";})
      (ignore "Ignore right stick click" {button = "RightStick";})
      (ignore "Ignore screenshot" {button = "Screenshot";})
      (stickAxis "RightStick" "Scroll description up" "up" "KeyF8")
      (stickAxis "RightStick" "Scroll description down" "down" "KeyF9")
      (ignore "Ignore right stick left" {
        axis = {
          name = "RightStick";
          direction = "left";
        };
      })
      (ignore "Ignore right stick right" {
        axis = {
          name = "RightStick";
          direction = "right";
        };
      })
      (ignore "Ignore left trigger" {trigger.name = "LeftTrigger";})
      (ignore "Ignore digital left trigger" {button = "LeftTrigger";})
      (ignore "Ignore digital right trigger" {button = "RightTrigger";})
      (ignore "Ignore right trigger" {trigger.name = "RightTrigger";})
    ];
  };
  profiles.game = {
    version = 1;
    kind = "DeviceProfile";
    name = "Theatre Gamepad";
    description = "Match Nintendo face-button letters to Xbox prompts; Home belongs to the session.";
    mapping = [
      (button "Nintendo A to Xbox A" "East" {gamepad.button = "South";})
      (button "Nintendo B to Xbox B" "South" {gamepad.button = "East";})
      # hid-nintendo's X/Y letters already match the Xbox evdev capabilities.
      (button "Nintendo X to Xbox X" "North" {gamepad.button = "North";})
      (button "Nintendo Y to Xbox Y" "West" {gamepad.button = "West";})
      # Nintendo's digital triggers must become virtual Xbox trigger axes.
      (button "Nintendo ZL to Xbox LT" "LeftTrigger" {gamepad.trigger.name = "LeftTrigger";})
      (button "Nintendo ZR to Xbox RT" "RightTrigger" {gamepad.trigger.name = "RightTrigger";})
      (key "System Home" "Guide" "KeyF13")
    ];
  };
}
