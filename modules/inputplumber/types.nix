{
  lib,
  yamlValue,
}: let
  inherit (lib) types;
  # Native option types for InputPlumber 0.81.0. Keep these in step with its
  # configuration formats when upgrading; the module check compares generated
  # YAML to the schemas shipped by the selected package.
  submodule = options: types.submodule {inherit options;};
  required = type: description:
    lib.mkOption {
      inherit type description;
      # List options otherwise have an implicit empty value, which would hide a
      # missing required field when the YAML generator enumerates config attrs.
      default = throw "Required InputPlumber setting is missing.";
      defaultText = lib.literalExpression "required";
    };
  optional = type: description:
    lib.mkOption {
      type = types.nullOr type;
      default = null;
      inherit description;
    };
  enumWords = text: types.enum (lib.filter (value: builtins.isString value && value != "") (builtins.split "[[:space:]]+" text));
  matrixVector = types.addCheck (types.listOf types.number) (value: builtins.length value == 3);
  device = submodule {
    version = required (types.enum [1]) "Schema version number";
    kind = required (types.enum ["CompositeDevice"]) "The type of configuration schema";
    name = required types.str "Name of the composite device mapping";
    single_source = optional types.bool "DEPRECATED: use 'maximum_sources' instead. If true, this composite device should only use one source device. Defaults to false.";
    maximum_sources = optional types.int "Maximum number of source devices that this composite device can manage. When this composite device reaches this maximum and a new matching source device is detected, a new composite device will be created instead of adding the source device to the existing one. Any value less than 1 indicates no maximum. Defaults to 0 (unlimited).";
    matches = required (types.listOf deviceMatch) "Only use this profile if *any* of the given DMI system matches match. If this list is empty, then the source devices will *always* be checked.";
    source_devices = required (types.listOf sourceDevice) "One or more source devices to combine into a single virtual device. The events from these devices will be watched and translated according to the event map.";
    capability_map_id = optional types.str "The ID of a device event mapping in the 'capability_maps' directory";
    options = optional deviceOptions "InputPlumber options setting.";
    target_devices = optional (types.listOf (enumWords ''
      mouse keyboard gamepad hori-steam xb360 xbox-elite xbox-series deck ds5 ds5-edge touchpad
      touchscreen
    '')) "Target input devices to emulate by default.";
  };
  deviceOptions = submodule {
    auto_manage = optional types.bool "If true, InputPlumber will automatically try to manage the input device. If this is false, InputPlumber will not try to manage the device unless an external service enables management of the device. Defaults to 'false'";
    persist = optional types.bool "If true, InputPlumber will not stop the CompositeDevice if all the SourceDevices have stopped. This will persist the virtual TargetDevice to allow reconnecting a SourceDevice and resuming input. Defaults to 'false'";
  };
  deviceMatch = submodule {
    dmi_data = optional dmiMatch "InputPlumber dmi_data setting.";
    udev = optional udevMatch "InputPlumber udev setting.";
  };
  dmiMatch = submodule {
    bios_release = optional types.str "BIOS release to match found at /sys/class/dmi/id/bios_release";
    bios_vendor = optional types.str "BIOS vendor to match found at /sys/class/dmi/id/bios_vendor";
    bios_version = optional types.str "BIOS version to match found at /sys/class/dmi/id/bios_version";
    board_name = optional types.str "Board name to match found at /sys/class/dmi/id/board_name";
    product_name = optional types.str "Product name to match found at /sys/class/dmi/id/product_name";
    product_version = optional types.str "Product version to match found at /sys/class/dmi/id/product_version";
    product_sku = optional types.str "Product SKU to match found at /sys/class/dmi/id/product_sku";
    sys_vendor = optional types.str "System vendor to match found at /sys/class/dmi/id/sys_vendor";
    cpu_model = optional types.str "CPU model to match from 'lscpu'";
    cpu_vendor = optional types.str "CPU vendor to match from 'lscpu'";
  };
  sourceDevice = submodule {
    group = required (enumWords ''
      keyboard mouse gamepad touchscreen imu led
    '') "Custom group identifier for the source device. This is used by the event mappings to determine what source inputs should be mapped.";
    ignore = optional types.bool "If true, this source device will be ignored and not managed by InputPlumber. Defaults to false.";
    blocked = optional types.bool "If true, device will be grabbed but no events from this device will reach target devices. Defaults to false.";
    passthrough = optional types.bool "If true, events will be read from this device, but the source device will not be hidden or grabbed. Defaults to false.";
    udev = optional udevMatch "InputPlumber udev setting.";
    evdev = optional evdevMatch "InputPlumber evdev setting.";
    hidraw = optional hidrawMatch "InputPlumber hidraw setting.";
    iio = optional iioMatch "InputPlumber iio setting.";
    led = optional ledMatch "InputPlumber led setting.";
    config = optional sourceDeviceConfig "InputPlumber config setting.";
    events = optional eventsConfig "InputPlumber events setting.";
    unique = optional types.bool "If false, any devices matching this description will be added to the existing composite device. Defaults to true.";
    capability_map_id = optional types.str "The ID of a device capability mapping in the 'capability_maps' folder";
  };
  sourceDeviceConfig = submodule {
    touchscreen = optional touchscreenConfig "InputPlumber touchscreen setting.";
    imu = optional imuConfig "InputPlumber imu setting.";
    led = optional ledConfig "InputPlumber led setting.";
  };
  touchscreenConfig = submodule {
    orientation = optional (enumWords ''
      normal left right upsidedown
    '') "Orientation of the touchscreen device. Defaults to normal.";
    width = optional types.int "Width of the touchscreen in pixels. If set, any virtual touchscreens will use this width instead of querying the source device for its size.";
    height = optional types.int "Height of the touchscreen in pixels. If set, any virtual touchscreens will use this height instead of querying the source device for its size.";
    override_source_size = optional types.bool "If true, the source device will use the width/height defined in this configuration instead of the size advertised by the device itself. Defaults to false.";
  };
  imuConfig = submodule {
    mount_matrix = optional mountMatrix "InputPlumber mount_matrix setting.";
  };
  ledConfig = submodule {
    fixed_color = optional color "InputPlumber fixed_color setting.";
  };
  udevMatch = submodule {
    attributes = optional (types.listOf udevKeyValue) "Device attributes to match. Attributes can be found by running `udevadm info --attribute-walk /path/to/device` and looking at fields that look like: `ATTR{name}==\"value\"`.";
    dev_node = optional types.str "Full device node path to match. E.g. '/dev/hidraw3', '/dev/input/event*'";
    dev_path = optional types.str "Full kernel device path to match. The path does not contain the sys mount point, but does start with a `/`. For example, the dev_path for `hidraw3` could be `/devices/pci0000:00/0000:00:08.1/.../hidraw/hidraw3`.";
    driver = optional types.str "Driver being used by the device (or parent devices) to match. E.g. `playstation`, `microsoft`";
    properties = optional (types.listOf udevKeyValue) "Device properties to match. Properties can be found by running `udevadm info -q property /path/to/device`.";
    subsystem = optional types.str "Subsystem to match. E.g. `input`, `hidraw`, `iio`";
    sys_name = optional types.str "Sysname to match. The sysname is typically the last part of the path to the device. E.g. `hidraw3`, `event6`";
    sys_path = optional types.str "Syspath to match. The syspath is an absolute path and includes the sys mount point. For example, the syspath for `hidraw3` could be `/sys/devices/pci0000:00/0000:00:08.1/.../hidraw/hidraw3`, which includes the sys mount point `/sys`.";
  };
  udevKeyValue = submodule {
    name = required types.str "Name of the property or attribute to match. Does NOT support globbing patterns.";
    value = optional types.str "Value of the property or attribute to match. Supports globbing patterns.";
  };
  evdevMatch = submodule {
    name = optional types.str "Name of the source device defined in /proc/bus/input/devices";
    handler = optional types.str "Event handler for the source device in /dev/input";
    phys_path = optional types.str "Phys path as defined in /proc/bus/input/devices";
    vendor_id = optional types.str "ID Vendor defined in /proc/bus/input/devices";
    product_id = optional types.str "ID Product defined in /proc/bus/input/devices";
  };
  hidrawMatch = submodule {
    handler = optional types.str "HIDRaw handler for the source device in /dev/hidraw*";
    vendor_id = optional types.int "InputPlumber vendor_id setting.";
    product_id = optional types.int "InputPlumber product_id setting.";
    interface_num = optional types.int "InputPlumber interface_num setting.";
    name = optional types.str "InputPlumber name setting.";
  };
  iioMatch = submodule {
    id = optional types.str "IIO handler for the source device in /sys/bus/iio/devices/*";
    name = optional types.str "InputPlumber name setting.";
    mount_matrix = optional mountMatrix "InputPlumber mount_matrix setting.";
  };
  ledMatch = submodule {
    id = optional types.str "Identifier of the LED device";
    name = optional types.str "InputPlumber name setting.";
  };
  mountMatrix = submodule {
    x = required matrixVector "Matrix for x value";
    y = required matrixVector "Matrix for y value";
    z = required matrixVector "Matrix for z value";
  };
  eventsConfig = submodule {
    exclude = optional (types.listOf types.str) "Events to exclude from being processed by a source device";
    include = optional (types.listOf types.str) "Events to include and be processed by a source device";
  };
  color = submodule {
    r = optional types.number "Red channel color (0-255)";
    g = optional types.number "Green channel color (0-255)";
    b = optional types.number "Blue channel color (0-255)";
  };
  profile = submodule {
    version = required (types.enum [1]) "InputPlumber version setting.";
    kind = required (types.enum ["DeviceProfile"]) "InputPlumber kind setting.";
    name = required types.str "Name of the device profile";
    description = optional types.str "Optional description of the device profile";
    target_devices = optional (types.listOf (enumWords ''
      deck deck-uhid ds5 ds5-edge gamepad hori-steam keyboard mouse touchpad touchscreen xb360
      xbox-elite xbox-series
    '')) "Target input device(s) to emulate. If unset, the target devices from the device profile will be used.";
    mapping = required (types.listOf profileMapping) "List of input mappings to translate when this profile is loaded";
  };
  profileMapping = submodule {
    name = required types.str "InputPlumber name setting.";
    source_event = required profileEvent "InputPlumber source_event setting.";
    target_events = required (types.listOf profileEvent) "InputPlumber target_events setting.";
  };
  profileEvent = submodule {
    keyboard = optional (enumWords ''
      KeyEsc Key1 Key2 Key3 Key4 Key5 Key6 Key7 Key8 Key9 Key0 KeyMinus KeyEqual KeyBackspace KeyTab
      KeyQ KeyW KeyE KeyR KeyT KeyY KeyU KeyI KeyO KeyP KeyLeftBrace KeyRightBrace KeyEnter
      KeyLeftCtrl KeyA KeyS KeyD KeyF KeyG KeyH KeyJ KeyK KeyL KeySemicolon KeyApostrophe KeyGrave
      KeyLeftShift KeyBackslash KeyBrightnessDown KeyBrightnessUp KeyZ KeyX KeyC KeyV KeyB KeyN KeyM
      KeyComma KeyDot KeySlash KeyRightShift KeyKpAsterisk KeyLeftAlt KeySpace KeyCapslock KeyF1
      KeyF2 KeyF3 KeyF4 KeyF5 KeyF6 KeyF7 KeyF8 KeyF9 KeyF10 KeyNumlock KeyScrollLock KeyKp7 KeyKp8
      KeyKp9 KeyKpMinus KeyKp4 KeyKp5 KeyKp6 KeyKpPlus KeyKp1 KeyKp2 KeyKp3 KeyKp0 KeyKpDot
      KeyZenkakuhankaku Key102nd KeyF11 KeyF12 KeyRo KeyKatakana KeyHiragana KeyHenkan
      KeyKatakanaHiragana KeyMuhenkan KeyKpJpComma KeyKpEnter KeyRightCtrl KeyKpSlash KeySysrq
      KeyRightAlt KeyHome KeyUp KeyPageUp KeyLeft KeyRight KeyEnd KeyDown KeyPageDown KeyInsert
      KeyDelete KeyMute KeyVolumeDown KeyVolumeUp KeyPower KeyKpEqual KeyPause KeyKpComma KeyHanja
      KeyYen KeyLeftMeta KeyRightMeta KeyCompose KeyStop KeyAgain KeyProps KeyUndo KeyFront KeyCopy
      KeyOpen KeyPaste KeyFind KeyCut KeyHelp KeyCalc KeySleep KeyWww KeyBack KeyForward KeyEjectCD
      KeyNextSong KeyPlayPause KeyPreviousSong KeyStopCD KeyRefresh KeyEdit KeyScrollUp KeyScrollDown
      KeyKpLeftParen KeyKpRightParen KeyF13 KeyF14 KeyF15 KeyF16 KeyF17 KeyF18 KeyF19 KeyF20 KeyF21
      KeyF22 KeyF23 KeyF24 KeyProg1
    '') "InputPlumber keyboard setting.";
    mouse = optional profileMouseEvent "InputPlumber mouse setting.";
    touchpad = optional profileTouchpadEvent "InputPlumber touchpad setting.";
    touchscreen = optional profileTouchEvent "InputPlumber touchscreen setting.";
    dbus = optional types.str "InputPlumber dbus setting.";
    gamepad = optional profileGamepadEvent "InputPlumber gamepad setting.";
  };
  profileMouseEvent = submodule {
    motion = optional profileMouseMotionEvent "InputPlumber motion setting.";
    button = optional (enumWords ''
      Left Right Middle WheelUp WheelDown WheelLeft WheelRight Extra1 Extra2
    '') "InputPlumber button setting.";
  };
  profileMouseMotionEvent = submodule {
    direction = optional (enumWords ''
      horizontal vertical left right up down
    '') "InputPlumber direction setting.";
    speed_pps = optional types.number "Speed of the target motion event in pixels per second";
  };
  profileTouchpadEvent = submodule {
    name = optional (enumWords ''
      LeftPad RightPad CenterPad
    '') "InputPlumber name setting.";
    touch = optional profileTouchEvent "InputPlumber touch setting.";
  };
  profileTouchEvent = submodule {
    motion = optional profileTouchMotionEvent "InputPlumber motion setting.";
    button = optional (enumWords ''
      Touch Press
    '') "InputPlumber button setting.";
  };
  profileTouchMotionEvent = submodule {
    region = optional (enumWords ''
      left right top bottom top-left top-right bottom-left bottom-right
    '') "Map from a specific region of the touch device";
    speed_pps = optional types.number "Speed of the target motion event in pixels per second";
  };
  profileGamepadEvent = submodule {
    axis = optional profileAxisEvent "InputPlumber axis setting.";
    gyro = optional profileGyroEvent "InputPlumber gyro setting.";
    trigger = optional profileTriggerEvent "InputPlumber trigger setting.";
    dial = optional profileDialEvent "InputPlumber dial setting.";
    button = optional (enumWords ''
      South East North West Start Select Guide QuickAccess QuickAccess2 Keyboard Screenshot DPadUp
      DPadDown DPadLeft DPadRight LeftBumper LeftTop LeftTrigger LeftPaddle1 LeftPaddle2 LeftPaddle3
      LeftStick LeftStickTouch LeftTouchpadTouch LeftTouchpadPress RightBumper RightTop RightTrigger
      RightPaddle1 RightPaddle2 RightPaddle3 RightStick RightStickTouch RightTouchpadTouch
      RightTouchpadPress
    '') "InputPlumber button setting.";
  };
  profileGyroEvent = submodule {
    name = required (enumWords ''
      Gyro1 Gyro2 Gyro3
    '') "InputPlumber name setting.";
    direction = optional (enumWords ''
      positive negative
    '') "InputPlumber direction setting.";
    deadzone = optional types.number "Optional deadzone from 0.0 - 1.0. When this deadzone threshold is crossed, this input is considered 'pressed'.";
    axis = optional (enumWords ''
      pitch roll yaw
    '') "Pitch, roll, or yaw";
  };
  profileTriggerEvent = submodule {
    name = required (enumWords ''
      LeftTrigger LeftTouchpadForce LeftStickForce RightTrigger RightTouchpadForce RightStickForce
    '') "InputPlumber name setting.";
    deadzone = optional types.number "Optional deadzone from 0.0 - 1.0. When this deadzone threshold is crossed, this input is considered 'pressed'.";
  };
  profileAxisEvent = submodule {
    name = required (enumWords ''
      LeftStick RightStick Hat0 Hat1 Hat2 Hat3
    '') "InputPlumber name setting.";
    direction = optional (enumWords ''
      horizontal vertical left right up down
    '') "Optional direction of the axis. Used when converting axis events into button events.";
    deadzone = optional types.number "Optional deadzone from 0.0 - 1.0. When this deadzone threshold is crossed, this input is considered 'pressed'.";
  };
  profileDialEvent = submodule {
    name = required (enumWords ''
      LeftStick RightStick
    '') "InputPlumber name setting.";
    direction = optional (enumWords ''
      clockwise counter-clockwise
    '') "Optional direction of the axis. Used when converting axis events into button events.";
  };
  mapMapping = submodule {
    name = required types.str "InputPlumber name setting.";
    target_event = required mapEvent "InputPlumber target_event setting.";
    source_events = required (types.listOf mapEvent) "InputPlumber source_events setting.";
  };
  mapEvent = submodule {
    keyboard = optional (enumWords ''
      KeyEsc Key1 Key2 Key3 Key4 Key5 Key6 Key7 Key8 Key9 Key0 KeyMinus KeyEqual KeyBackspace KeyTab
      KeyQ KeyW KeyE KeyR KeyT KeyY KeyU KeyI KeyO KeyP KeyLeftBrace KeyRightBrace KeyEnter
      KeyLeftCtrl KeyA KeyS KeyD KeyF KeyG KeyH KeyJ KeyK KeyL KeySemicolon KeyApostrophe KeyGrave
      KeyLeftShift KeyBackslash KeyZ KeyX KeyC KeyV KeyB KeyN KeyM KeyComma KeyDot KeySlash
      KeyRightShift KeyKpAsterisk KeyLeftAlt KeySpace KeyCapslock KeyF1 KeyF2 KeyF3 KeyF4 KeyF5 KeyF6
      KeyF7 KeyF8 KeyF9 KeyF10 KeyNumlock KeyScrollLock KeyKp7 KeyKp8 KeyKp9 KeyKpMinus KeyKp4 KeyKp5
      KeyKp6 KeyKpPlus KeyKp1 KeyKp2 KeyKp3 KeyKp0 KeyKpDot KeyZenkakuhankaku Key102nd KeyF11 KeyF12
      KeyRo KeyKatakana KeyHiragana KeyHenkan KeyKatakanaHiragana KeyMuhenkan KeyKpJpComma KeyKpEnter
      KeyRightCtrl KeyKpSlash KeySysrq KeyRightAlt KeyHome KeyUp KeyPageUp KeyLeft KeyRight KeyEnd
      KeyDown KeyPageDown KeyInsert KeyDelete KeyMute KeyVolumeDown KeyVolumeUp KeyPower KeyKpEqual
      KeyPause KeyKpComma KeyHanja KeyYen KeyLeftMeta KeyRightMeta KeyCompose KeyStop KeyAgain
      KeyProps KeyUndo KeyFront KeyCopy KeyOpen KeyPaste KeyFind KeyCut KeyHelp KeyCalc KeySleep
      KeyWww KeyBack KeyForward KeyEjectCD KeyNextSong KeyPlayPause KeyPreviousSong KeyStopCD
      KeyRefresh KeyEdit KeyScrollUp KeyScrollDown KeyKpLeftParen KeyKpRightParen KeyF13 KeyF14
      KeyF15 KeyF16 KeyF17 KeyF18 KeyF19 KeyF20 KeyF21 KeyF22 KeyF23 KeyF24 KeyProg1 KeyProg2
      KeyProg3 KeyProg4 KeyOk KeyExit KeyInfo KeyRootMenu KeyRed KeyGreen KeyYellow KeyBlue
    '') "InputPlumber keyboard setting.";
    mouse = optional mapMouseEvent "InputPlumber mouse setting.";
    touchpad = optional profileTouchpadEvent "InputPlumber touchpad setting.";
    touchscreen = optional profileTouchEvent "InputPlumber touchscreen setting.";
    dbus = optional (enumWords ''
      ui_guide ui_quick ui_context ui_option ui_select ui_accept ui_back ui_action ui_left ui_right
      ui_up ui_down ui_l1 ui_l2 ui_l3 ui_r1 ui_r2 ui_r3 ui_volume_up ui_volume_down ui_volume_mute
      ui_osk ui_screenshot ui_touch
    '') "InputPlumber dbus setting.";
    gamepad = optional mapGamepadEvent "InputPlumber gamepad setting.";
  };
  mapMouseEvent = submodule {
    motion = optional profileMouseMotionEvent "InputPlumber motion setting.";
    wheel = optional mapMouseWheelEvent "InputPlumber wheel setting.";
    button = optional (enumWords ''
      Left Right Middle WheelUp WheelDown WheelLeft WheelRight Extra1 Extra2
    '') "InputPlumber button setting.";
  };
  mapMouseWheelEvent = submodule {
    direction = optional (enumWords ''
      horizontal vertical left right up down
    '') "InputPlumber direction setting.";
  };
  mapGamepadEvent = submodule {
    axis = optional profileAxisEvent "InputPlumber axis setting.";
    gyro = optional profileGyroEvent "InputPlumber gyro setting.";
    trigger = optional profileTriggerEvent "InputPlumber trigger setting.";
    button = optional (enumWords ''
      DPadDown DPadLeft DPadRight DPadUp East Guide Keyboard LeftBumper LeftPaddle1 LeftPaddle2
      LeftPaddle3 LeftStick LeftStickTouch LeftTop LeftTouchpadPress LeftTouchpadTouch LeftTrigger
      North QuickAccess QuickAccess2 RightBumper RightPaddle1 RightPaddle2 RightPaddle3 RightStick
      RightStickTouch RightTop RightTouchpadPress RightTouchpadTouch RightTrigger Screenshot Select
      South Start West
    '') "InputPlumber button setting.";
  };
  v2SensorCapability = submodule {
    axis = optional types.str "InputPlumber axis setting.";
    deadzone = optional types.number "InputPlumber deadzone setting.";
    direction = optional types.str "InputPlumber direction setting.";
    name = required types.str "InputPlumber name setting.";
  };
  v2AxisCapability = submodule {
    deadzone = optional types.number "A value from 0.0-1.0 of how far an axis should be pressed in a particular direction in order for it to be considered \"pressed\"";
    direction = optional types.str "Direction of the axis to translate. Can be one of [\"vertical\", \"horizontal\", \"left\", \"right\", \"up\", \"down\"].";
    invert = optional types.bool "Invert all values of this axis with the matching direction";
    name = required types.str "InputPlumber name setting.";
    quadratic_scaling = optional types.bool "Use quadratic scaling for more precise control with small stick movements";
  };
  v2AxisDirection = enumWords ''
    none positive negative
  '';
  v2CapabilityConfig = submodule {
    accelerometer = optional v2SensorCapability "InputPlumber accelerometer setting.";
    dbus = optional types.str "InputPlumber dbus setting.";
    gamepad = optional v2GamepadCapability "InputPlumber gamepad setting.";
    gyroscope = optional v2SensorCapability "InputPlumber gyroscope setting.";
    keyboard = optional types.str "InputPlumber keyboard setting.";
    mouse = optional v2MouseCapability "InputPlumber mouse setting.";
    touchpad = optional v2TouchpadCapability "InputPlumber touchpad setting.";
    touchscreen = optional v2TouchCapability "InputPlumber touchscreen setting.";
  };
  v2CapabilityMapping = submodule {
    mapping_type = optional v2MappingType "InputPlumber mapping_type setting.";
    name = required types.str "InputPlumber name setting.";
    source_events = required (types.listOf v2SourceMapping) "InputPlumber source_events setting.";
    target_event = required v2CapabilityConfig "InputPlumber target_event setting.";
  };
  v2DialCapability = submodule {
    direction = optional types.str "InputPlumber direction setting.";
    name = required types.str "InputPlumber name setting.";
  };
  v2EvdevConfig = submodule {
    axis_direction = optional v2AxisDirection "InputPlumber axis_direction setting.";
    event_code = required v2EventCode "InputPlumber event_code setting.";
    event_type = required v2EventType "InputPlumber event_type setting.";
    event_value = optional (types.addCheck types.int (value: value >= 0 && value <= 65535)) "InputPlumber event_value setting.";
    value_type = required v2ValueType "InputPlumber value_type setting.";
  };
  v2EvdevMappingType = enumWords ''
    chord delayed_chord multi_source
  '';
  v2EventCode = enumWords ''
    SYN_REPORT SYN_CONFIG SYN_MT_REPORT SYN_DROPPED KEY_RESERVED KEY_ESC KEY1 KEY2 KEY3 KEY4 KEY5
    KEY6 KEY7 KEY8 KEY9 KEY0 KEY_MINUS KEY_EQUAL KEY_BACKSPACE KEY_TAB KEY_Q KEY_W KEY_E KEY_R
    KEY_T KEY_Y KEY_U KEY_I KEY_O KEY_P KEY_LEFTBRACE KEY_RIGHTBRACE KEY_ENTER KEY_LEFTCTRL KEY_A
    KEY_S KEY_D KEY_F KEY_G KEY_H KEY_J KEY_K KEY_L KEY_SEMICOLON KEY_APOSTROPHE KEY_GRAVE
    KEY_LEFTSHIFT KEY_BACKSLASH KEY_Z KEY_X KEY_C KEY_V KEY_B KEY_N KEY_M KEY_COMMA KEY_DOT
    KEY_SLASH KEY_RIGHTSHIFT KEY_KPASTERISK KEY_LEFTALT KEY_SPACE KEY_CAPSLOCK KEY_F1 KEY_F2 KEY_F3
    KEY_F4 KEY_F5 KEY_F6 KEY_F7 KEY_F8 KEY_F9 KEY_F10 KEY_NUMLOCK KEY_SCROLLLOCK KEY_KP7 KEY_KP8
    KEY_KP9 KEY_KPMINUS KEY_KP4 KEY_KP5 KEY_KP6 KEY_KPPLUS KEY_KP1 KEY_KP2 KEY_KP3 KEY_KP0
    KEY_KPDOT KEY_ZENKAKUHANKAKU KEY102ND KEY_F11 KEY_F12 KEY_RO KEY_KATAKANA KEY_HIRAGANA
    KEY_HENKAN KEY_KATAKANAHIRAGANA KEY_MUHENKAN KEY_KPJPCOMMA KEY_KPENTER KEY_RIGHTCTRL
    KEY_KPSLASH KEY_SYSRQ KEY_RIGHTALT KEY_LINEFEED KEY_HOME KEY_UP KEY_PAGEUP KEY_LEFT KEY_RIGHT
    KEY_END KEY_DOWN KEY_PAGEDOWN KEY_INSERT KEY_DELETE KEY_MACRO KEY_MUTE KEY_VOLUMEDOWN
    KEY_VOLUMEUP KEY_POWER KEY_KPEQUAL KEY_KPPLUSMINUS KEY_PAUSE KEY_SCALE KEY_KPCOMMA KEY_HANGEUL
    KEY_HANJA KEY_YEN KEY_LEFTMETA KEY_RIGHTMETA KEY_COMPOSE KEY_STOP KEY_AGAIN KEY_PROPS KEY_UNDO
    KEY_FRONT KEY_COPY KEY_OPEN KEY_PASTE KEY_FIND KEY_CUT KEY_HELP KEY_MENU KEY_CALC KEY_SETUP
    KEY_SLEEP KEY_WAKEUP KEY_FILE KEY_SENDFILE KEY_DELETEFILE KEY_XFER KEY_PROG1 KEY_PROG2 KEY_WWW
    KEY_MSDOS KEY_SCREENLOCK KEY_ROTATE_DISPLAY KEY_CYCLEWINDOWS KEY_MAIL KEY_BOOKMARKS
    KEY_COMPUTER KEY_BACK KEY_FORWARD KEY_CLOSECD KEY_EJECTCD KEY_EJECTCLOSECD KEY_NEXTSONG
    KEY_PLAYPAUSE KEY_PREVIOUSSONG KEY_STOPCD KEY_RECORD KEY_REWIND KEY_PHONE KEY_ISO KEY_CONFIG
    KEY_HOMEPAGE KEY_REFRESH KEY_EXIT KEY_MOVE KEY_EDIT KEY_SCROLLUP KEY_SCROLLDOWN KEY_KPLEFTPAREN
    KEY_KPRIGHTPAREN KEY_NEW KEY_REDO KEY_F13 KEY_F14 KEY_F15 KEY_F16 KEY_F17 KEY_F18 KEY_F19
    KEY_F20 KEY_F21 KEY_F22 KEY_F23 KEY_F24 KEY_PLAYCD KEY_PAUSECD KEY_PROG3 KEY_PROG4
    KEY_ALL_APPLICATIONS KEY_SUSPEND KEY_CLOSE KEY_PLAY KEY_FASTFORWARD KEY_BASSBOOST KEY_PRINT
    KEY_HP KEY_CAMERA KEY_SOUND KEY_QUESTION KEY_EMAIL KEY_CHAT KEY_SEARCH KEY_CONNECT KEY_FINANCE
    KEY_SPORT KEY_SHOP KEY_ALTERASE KEY_CANCEL KEY_BRIGHTNESSDOWN KEY_BRIGHTNESSUP KEY_MEDIA
    KEY_SWITCHVIDEOMODE KEY_KBDILLUMTOGGLE KEY_KBDILLUMDOWN KEY_KBDILLUMUP KEY_SEND KEY_REPLY
    KEY_FORWARDMAIL KEY_SAVE KEY_DOCUMENTS KEY_BATTERY KEY_BLUETOOTH KEY_WLAN KEY_UWB KEY_UNKNOWN
    KEY_VIDEO_NEXT KEY_VIDEO_PREV KEY_BRIGHTNESS_CYCLE KEY_BRIGHTNESS_AUTO KEY_DISPLAY_OFF KEY_WWAN
    KEY_RFKILL KEY_MICMUTE BTN_MISC BTN0 BTN1 BTN2 BTN3 BTN4 BTN5 BTN6 BTN7 BTN8 BTN9 BTN_MOUSE
    BTN_LEFT BTN_RIGHT BTN_MIDDLE BTN_SIDE BTN_EXTRA BTN_FORWARD BTN_BACK BTN_TASK BTN_JOYSTICK
    BTN_TRIGGER BTN_THUMB BTN_THUMB2 BTN_TOP BTN_TOP2 BTN_PINKIE BTN_BASE BTN_BASE2 BTN_BASE3
    BTN_BASE4 BTN_BASE5 BTN_BASE6 BTN_DEAD BTN_GAMEPAD BTN_SOUTH BTN_EAST BTN_C BTN_NORTH BTN_WEST
    BTN_Z BTN_TL BTN_TR BTN_TL2 BTN_TR2 BTN_SELECT BTN_START BTN_MODE BTN_THUMBL BTN_THUMBR
    BTN_DIGI BTN_TOOL_PEN BTN_TOOL_RUBBER BTN_TOOL_BRUSH BTN_TOOL_PENCIL BTN_TOOL_AIRBRUSH
    BTN_TOOL_FINGER BTN_TOOL_MOUSE BTN_TOOL_LENS BTN_TOOL_QUINTTAP BTN_STYLUS3 BTN_TOUCH BTN_STYLUS
    BTN_STYLUS2 BTN_TOOL_DOUBLETAP BTN_TOOL_TRIPLETAP BTN_TOOL_QUADTAP BTN_WHEEL BTN_GEAR_DOWN
    BTN_GEAR_UP KEY_OK KEY_SELECT KEY_GOTO KEY_CLEAR KEY_POWER2 KEY_OPTION KEY_INFO KEY_TIME
    KEY_VENDOR KEY_ARCHIVE KEY_PROGRAM KEY_CHANNEL KEY_FAVORITES KEY_EPG KEY_PVR KEY_MHP
    KEY_LANGUAGE KEY_TITLE KEY_SUBTITLE KEY_ANGLE KEY_FULL_SCREEN KEY_MODE KEY_KEYBOARD
    KEY_ASPECT_RATIO KEY_PC KEY_TV KEY_TV2 KEY_VCR KEY_VCR2 KEY_SAT KEY_SAT2 KEY_CD KEY_TAPE
    KEY_RADIO KEY_TUNER KEY_PLAYER KEY_TEXT KEY_DVD KEY_AUX KEY_MP3 KEY_AUDIO KEY_VIDEO
    KEY_DIRECTORY KEY_LIST KEY_MEMO KEY_CALENDAR KEY_RED KEY_GREEN KEY_YELLOW KEY_BLUE
    KEY_CHANNELUP KEY_CHANNELDOWN KEY_FIRST KEY_LAST KEY_AB KEY_NEXT KEY_RESTART KEY_SLOW
    KEY_SHUFFLE KEY_BREAK KEY_PREVIOUS KEY_DIGITS KEY_TEEN KEY_TWEN KEY_VIDEOPHONE KEY_GAMES
    KEY_ZOOMIN KEY_ZOOMOUT KEY_ZOOMRESET KEY_WORDPROCESSOR KEY_EDITOR KEY_SPREADSHEET
    KEY_GRAPHICSEDITOR KEY_PRESENTATION KEY_DATABASE KEY_NEWS KEY_VOICEMAIL KEY_ADDRESSBOOK
    KEY_MESSENGER KEY_DISPLAYTOGGLE KEY_SPELLCHECK KEY_LOGOFF KEY_DOLLAR KEY_EURO KEY_FRAMEBACK
    KEY_FRAMEFORWARD KEY_CONTEXT_MENU KEY_MEDIA_REPEAT KEY10CHANNELSUP KEY10CHANNELSDOWN KEY_IMAGES
    KEY_NOTIFICATION_CENTER KEY_PICKUP_PHONE KEY_HANGUP_PHONE KEY_LINK_PHONE KEY_DEL_EOL
    KEY_DEL_EOS KEY_INS_LINE KEY_DEL_LINE KEY_FN KEY_FN_ESC KEY_FN_F1 KEY_FN_F2 KEY_FN_F3 KEY_FN_F4
    KEY_FN_F5 KEY_FN_F6 KEY_FN_F7 KEY_FN_F8 KEY_FN_F9 KEY_FN_F10 KEY_FN_F11 KEY_FN_F12 KEY_FN1
    KEY_FN2 KEY_FN_D KEY_FN_E KEY_FN_F KEY_FN_S KEY_FN_B KEY_FN_RIGHT_SHIFT KEY_BRL_DOT1
    KEY_BRL_DOT2 KEY_BRL_DOT3 KEY_BRL_DOT4 KEY_BRL_DOT5 KEY_BRL_DOT6 KEY_BRL_DOT7 KEY_BRL_DOT8
    KEY_BRL_DOT9 KEY_BRL_DOT10 KEY_NUMERIC0 KEY_NUMERIC1 KEY_NUMERIC2 KEY_NUMERIC3 KEY_NUMERIC4
    KEY_NUMERIC5 KEY_NUMERIC6 KEY_NUMERIC7 KEY_NUMERIC8 KEY_NUMERIC9 KEY_NUMERIC_STAR
    KEY_NUMERIC_POUND KEY_NUMERIC_A KEY_NUMERIC_B KEY_NUMERIC_C KEY_NUMERIC_D KEY_CAMERA_FOCUS
    KEY_WPS_BUTTON KEY_TOUCHPAD_TOGGLE KEY_TOUCHPAD_ON KEY_TOUCHPAD_OFF KEY_CAMERA_ZOOMIN
    KEY_CAMERA_ZOOMOUT KEY_CAMERA_UP KEY_CAMERA_DOWN KEY_CAMERA_LEFT KEY_CAMERA_RIGHT
    KEY_ATTENDANT_ON KEY_ATTENDANT_OFF KEY_ATTENDANT_TOGGLE KEY_LIGHTS_TOGGLE BTN_DPAD_UP
    BTN_DPAD_DOWN BTN_DPAD_LEFT BTN_DPAD_RIGHT KEY_ALS_TOGGLE KEY_ROTATE_LOCK_TOGGLE
    KEY_REFRESH_RATE_TOGGLE KEY_BUTTONCONFIG KEY_TASKMANAGER KEY_JOURNAL KEY_CONTROLPANEL
    KEY_APPSELECT KEY_SCREENSAVER KEY_VOICECOMMAND KEY_ASSISTANT KEY_KBD_LAYOUT_NEXT
    KEY_EMOJI_PICKER KEY_DICTATE KEY_CAMERA_ACCESS_ENABLE KEY_CAMERA_ACCESS_DISABLE
    KEY_CAMERA_ACCESS_TOGGLE KEY_ACCESSIBILITY KEY_DO_NOT_DISTURB KEY_BRIGHTNESS_MIN
    KEY_BRIGHTNESS_MAX KEY_KBDINPUTASSIST_PREV KEY_KBDINPUTASSIST_NEXT KEY_KBDINPUTASSIST_PREVGROUP
    KEY_KBDINPUTASSIST_NEXTGROUP KEY_KBDINPUTASSIST_ACCEPT KEY_KBDINPUTASSIST_CANCEL KEY_RIGHT_UP
    KEY_RIGHT_DOWN KEY_LEFT_UP KEY_LEFT_DOWN KEY_ROOT_MENU KEY_MEDIA_TOP_MENU KEY_NUMERIC11
    KEY_NUMERIC12 KEY_AUDIO_DESC KEY3D_MODE KEY_NEXT_FAVORITE KEY_STOP_RECORD KEY_PAUSE_RECORD
    KEY_VOD KEY_UNMUTE KEY_FASTREVERSE KEY_SLOWREVERSE KEY_DATA KEY_ONSCREEN_KEYBOARD
    KEY_PRIVACY_SCREEN_TOGGLE KEY_SELECTIVE_SCREENSHOT KEY_NEXT_ELEMENT KEY_PREVIOUS_ELEMENT
    KEY_AUTOPILOT_ENGAGE_TOGGLE KEY_MARK_WAYPOINT KEY_SOS KEY_NAV_CHART KEY_FISHING_CHART
    KEY_SINGLE_RANGE_RADAR KEY_DUAL_RANGE_RADAR KEY_RADAR_OVERLAY KEY_TRADITIONAL_SONAR
    KEY_CLEARVU_SONAR KEY_SIDEVU_SONAR KEY_NAV_INFO KEY_BRIGHTNESS_MENU KEY_MACRO1 KEY_MACRO2
    KEY_MACRO3 KEY_MACRO4 KEY_MACRO5 KEY_MACRO6 KEY_MACRO7 KEY_MACRO8 KEY_MACRO9 KEY_MACRO10
    KEY_MACRO11 KEY_MACRO12 KEY_MACRO13 KEY_MACRO14 KEY_MACRO15 KEY_MACRO16 KEY_MACRO17 KEY_MACRO18
    KEY_MACRO19 KEY_MACRO20 KEY_MACRO21 KEY_MACRO22 KEY_MACRO23 KEY_MACRO24 KEY_MACRO25 KEY_MACRO26
    KEY_MACRO27 KEY_MACRO28 KEY_MACRO29 KEY_MACRO30 KEY_MACRO_RECORD_START KEY_MACRO_RECORD_STOP
    KEY_MACRO_PRESET_CYCLE KEY_MACRO_PRESET1 KEY_MACRO_PRESET2 KEY_MACRO_PRESET3 KEY_KBD_LCD_MENU1
    KEY_KBD_LCD_MENU2 KEY_KBD_LCD_MENU3 KEY_KBD_LCD_MENU4 KEY_KBD_LCD_MENU5 BTN_TRIGGER_HAPPY
    BTN_TRIGGER_HAPPY1 BTN_TRIGGER_HAPPY2 BTN_TRIGGER_HAPPY3 BTN_TRIGGER_HAPPY4 BTN_TRIGGER_HAPPY5
    BTN_TRIGGER_HAPPY6 BTN_TRIGGER_HAPPY7 BTN_TRIGGER_HAPPY8 BTN_TRIGGER_HAPPY9 BTN_TRIGGER_HAPPY10
    BTN_TRIGGER_HAPPY11 BTN_TRIGGER_HAPPY12 BTN_TRIGGER_HAPPY13 BTN_TRIGGER_HAPPY14
    BTN_TRIGGER_HAPPY15 BTN_TRIGGER_HAPPY16 BTN_TRIGGER_HAPPY17 BTN_TRIGGER_HAPPY18
    BTN_TRIGGER_HAPPY19 BTN_TRIGGER_HAPPY20 BTN_TRIGGER_HAPPY21 BTN_TRIGGER_HAPPY22
    BTN_TRIGGER_HAPPY23 BTN_TRIGGER_HAPPY24 BTN_TRIGGER_HAPPY25 BTN_TRIGGER_HAPPY26
    BTN_TRIGGER_HAPPY27 BTN_TRIGGER_HAPPY28 BTN_TRIGGER_HAPPY29 BTN_TRIGGER_HAPPY30
    BTN_TRIGGER_HAPPY31 BTN_TRIGGER_HAPPY32 BTN_TRIGGER_HAPPY33 BTN_TRIGGER_HAPPY34
    BTN_TRIGGER_HAPPY35 BTN_TRIGGER_HAPPY36 BTN_TRIGGER_HAPPY37 BTN_TRIGGER_HAPPY38
    BTN_TRIGGER_HAPPY39 BTN_TRIGGER_HAPPY40 REL_X REL_Y REL_Z REL_RX REL_RY REL_RZ REL_HWHEEL
    REL_DIAL REL_WHEEL REL_MISC REL_RESERVED REL_WHEEL_HI_RES REL_HWHEEL_HI_RES ABS_X ABS_Y ABS_Z
    ABS_RX ABS_RY ABS_RZ ABS_THROTTLE ABS_RUDDER ABS_WHEEL ABS_GAS ABS_BRAKE ABS_HAT0X ABS_HAT0Y
    ABS_HAT1X ABS_HAT1Y ABS_HAT2X ABS_HAT2Y ABS_HAT3X ABS_HAT3Y ABS_PRESSURE ABS_DISTANCE
    ABS_TILT_X ABS_TILT_Y ABS_TOOL_WIDTH ABS_VOLUME ABS_PROFILE ABS_MISC ABS_RESERVED ABS_MT_SLOT
    ABS_MT_TOUCH_MAJOR ABS_MT_TOUCH_MINOR ABS_MT_WIDTH_MAJOR ABS_MT_WIDTH_MINOR ABS_MT_ORIENTATION
    ABS_MT_POSITION_X ABS_MT_POSITION_Y ABS_MT_TOOL_TYPE ABS_MT_BLOB_ID ABS_MT_TRACKING_ID
    ABS_MT_PRESSURE ABS_MT_DISTANCE ABS_MT_TOOL_X ABS_MT_TOOL_Y SW_LID SW_TABLET_MODE
    SW_HEADPHONE_INSERT SW_RFKILL_ALL SW_MICROPHONE_INSERT SW_DOCK SW_LINEOUT_INSERT
    SW_JACK_PHYSICAL_INSERT SW_VIDEOOUT_INSERT SW_CAMERA_LENS_COVER SW_KEYPAD_SLIDE
    SW_FRONT_PROXIMITY SW_ROTATE_LOCK SW_LINEIN_INSERT SW_MUTE_DEVICE SW_PEN_INSERTED
    SW_MACHINE_COVER MSC_SERIAL MSC_PULSELED MSC_GESTURE MSC_RAW MSC_SCAN MSC_TIMESTAMP LED_NUML
    LED_CAPSL LED_SCROLLL LED_COMPOSE LED_KANA LED_SLEEP LED_SUSPEND LED_MUTE LED_MISC LED_MAIL
    LED_CHARGING REP_DELAY REP_PERIOD SND_CLICK SND_BELL SND_TONE
  '';
  v2EventType = enumWords ''
    SYNC KEY REL ABS MSC SW LED SND REP FF PWR FF_STATUS UINPUT
  '';
  v2GamepadCapability = submodule {
    accelerometer = optional v2SensorCapability "InputPlumber accelerometer setting.";
    axis = optional v2AxisCapability "InputPlumber axis setting.";
    button = optional types.str "InputPlumber button setting.";
    dial = optional v2DialCapability "InputPlumber dial setting.";
    gyro = optional v2SensorCapability "InputPlumber gyro setting.";
    trigger = optional v2TriggerCapability "InputPlumber trigger setting.";
  };
  v2HidrawConfig = submodule {
    bit_offset = required (types.addCheck types.int (value: value >= 0 && value <= 255)) "InputPlumber bit_offset setting.";
    byte_start = required (types.addCheck types.int (value: value >= 0)) "InputPlumber byte_start setting.";
    input_type = required types.str "InputPlumber input_type setting.";
    report_id = required (types.addCheck types.int (value: value >= 0)) "InputPlumber report_id setting.";
  };
  v2MappingType = submodule {
    evdev = optional v2EvdevMappingType "InputPlumber evdev setting.";
  };
  v2MouseCapability = submodule {
    button = optional types.str "InputPlumber button setting.";
    motion = optional v2MouseMotionCapability "InputPlumber motion setting.";
    wheel = optional v2MouseWheelCapability "InputPlumber wheel setting.";
  };
  v2MouseMotionCapability = submodule {
    direction = optional types.str "InputPlumber direction setting.";
    speed_pps = optional (types.addCheck types.int (value: value >= 0)) "InputPlumber speed_pps setting.";
  };
  v2MouseWheelCapability = submodule {
    direction = optional types.str "InputPlumber direction setting.";
  };
  v2SourceMapping = submodule {
    capability = optional v2CapabilityConfig "InputPlumber capability setting.";
    evdev = optional v2EvdevConfig "InputPlumber evdev setting.";
    hidraw = optional v2HidrawConfig "InputPlumber hidraw setting.";
  };
  v2TouchCapability = submodule {
    button = optional types.str "InputPlumber button setting.";
    motion = optional v2TouchMotionCapability "InputPlumber motion setting.";
  };
  v2TouchMotionCapability = submodule {
    region = optional types.str "InputPlumber region setting.";
    speed_pps = optional (types.addCheck types.int (value: value >= 0)) "InputPlumber speed_pps setting.";
  };
  v2TouchpadCapability = submodule {
    name = required types.str "InputPlumber name setting.";
    touch = required v2TouchCapability "InputPlumber touch setting.";
  };
  v2TriggerCapability = submodule {
    deadzone = optional types.number "InputPlumber deadzone setting.";
    name = required types.str "InputPlumber name setting.";
  };
  v2ValueType = enumWords ''
    button trigger joystick_x joystick_y imu_x imu_y imu_z
  '';
in rec {
  inherit device profile;
  capabilityMap = types.submodule ({config, ...}: {
    # Select mapping types after version definitions have merged, so modules
    # can contribute the version and mappings independently.
    options = {
      version = lib.mkOption {
        type = types.enum [1 2];
        default = 1;
        description = "Capability-map format version. Version 1 is the default.";
      };
      kind = required (types.enum ["CapabilityMap"]) "Configuration kind.";
      name = required types.str "Capability-map display name.";
      id = required types.str "Identifier referenced by composite devices.";
      mapping = required (types.listOf (
        if config.version == 1
        then mapMapping
        else v2CapabilityMapping
      )) "Capability mappings in the selected format version.";
      filtered_events = lib.mkOption {
        # InputPlumber's v1 format leaves individual filtered events untyped.
        type =
          if config.version == 1
          then types.listOf yamlValue
          else types.enum [null];
        default =
          if config.version == 1
          then throw "InputPlumber v1 capability maps require filtered_events."
          else null;
        defaultText = lib.literalExpression "required for v1; omitted for v2";
        description = "Filtered events (v1 only).";
      };
    };
  });
  # Omit unset optional fields, preserving deliberately empty lists and the
  # arbitrary values in v1 filtered_events.
  omitNulls = value:
    if builtins.isAttrs value
    then
      lib.mapAttrs (name: item:
        if name == "filtered_events"
        then item
        else omitNulls item)
      (lib.filterAttrs (_: item: item != null) value)
    else if builtins.isList value
    then map omitNulls value
    else value;
}
