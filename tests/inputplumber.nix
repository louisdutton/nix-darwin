{
  pkgs,
  nixpkgs,
}: let
  makeConfig = settings:
    (nixpkgs.lib.nixosSystem {
      system = pkgs.stdenv.hostPlatform.system;
      modules = [
        ../modules/inputplumber.nix
        {
          services.inputplumber = settings;
          system.stateVersion = "26.05";
        }
      ];
    }).config;
  theatreSettings = import ../config/kodi/inputplumber.nix;
  theatre = makeConfig (theatreSettings // {enable = true;});
  generic = makeConfig {
    enable = true;
    devices.test =
      theatreSettings.devices."10-theatre-pro"
      // {
        # Auto-capture is a host policy, not a requirement for all device configs.
        options.auto_manage = false;
      };
    capabilityMaps.test = {
      version = 1;
      kind = "CapabilityMap";
      name = "Test capability map";
      id = "nixos-module-test";
      mapping = [];
      filtered_events = [];
    };
    capabilityMaps.test-v2 = pkgs.lib.mkMerge [
      {
        version = 2;
        kind = "CapabilityMap";
        name = "Test capability map v2";
        id = "nixos-module-test-v2";
      }
      {
        mapping = [
          {
            name = "Evdev enter";
            mapping_type.evdev = "chord";
            source_events = [
              {
                evdev = {
                  event_type = "KEY";
                  event_code = "KEY_ENTER";
                  value_type = "button";
                };
              }
            ];
            target_event.keyboard = "KeyEnter";
          }
        ];
      }
    ];
  };
  disabled = makeConfig {
    enable = false;
    inherit (theatreSettings) profiles;
  };
  invalidDefault = makeConfig {
    enable = true;
    defaultProfile = "missing";
  };
  invalidName = makeConfig {
    enable = true;
    profiles."../escape" = theatreSettings.profiles.kodi;
  };
  accepts = cfg: pkgs.lib.all (entry: entry.assertion || !(pkgs.lib.hasPrefix "InputPlumber" entry.message || pkgs.lib.hasPrefix "services.inputplumber" entry.message)) cfg.assertions;
  evaluates = settings: let
    cfg = (makeConfig settings).services.inputplumber;
  in
    (builtins.tryEval (builtins.deepSeq {inherit (cfg) devices profiles capabilityMaps;} true)).success;
  rejects = settings: !evaluates settings;
  profile = theatreSettings.profiles.kodi;
  device = theatreSettings.devices."10-theatre-pro";
  badProfiles = [
    (builtins.removeAttrs profile ["name"])
    (profile // {kind = "CompositeDevice";})
    (profile // {version = 2;})
    (profile // {mapping = "invalid";})
    (profile // {unknown = true;})
    (profile
      // {
        mapping = [
          {
            name = "Bad key";
            source_event.keyboard = "KeyNotAKey";
            target_events = [];
          }
        ];
      })
    (profile
      // {
        mapping = [
          {
            name = "Bad axis";
            source_event.gamepad.axis.name = "NotAnAxis";
            target_events = [];
          }
        ];
      })
    (profile
      // {
        mapping = [
          {
            name = "Missing target";
            source_event.keyboard = "KeyEnter";
          }
        ];
      })
  ];
  badDevices = [
    (device // {options.auto_manage = "yes";})
    (device
      // {
        source_devices = [
          {
            group = "gamepad";
            evdev.vendor_id = 1406;
          }
        ];
      })
    (device
      // {
        source_devices = [
          {
            group = "imu";
            iio.mount_matrix = {
              x = [1 0];
              y = [0 1 0];
              z = [0 0 1];
            };
          }
        ];
      })
  ];
  badMaps = [
    {
      version = 3;
      kind = "CapabilityMap";
      name = "Unsupported";
      id = "test";
      mapping = [];
    }
    {
      version = 1;
      kind = "CapabilityMap";
      name = "Missing filtered_events";
      id = "test";
      mapping = [];
    }
    {
      version = 2;
      kind = "CapabilityMap";
      name = "Bad evdev";
      id = "test";
      mapping = [
        {
          name = "Bad";
          source_events = [
            {
              evdev = {
                event_type = "KEY";
                event_code = "NOT_A_CODE";
                value_type = "button";
              };
            }
          ];
          target_event.keyboard = "KeyEnter";
        }
      ];
    }
    {
      version = 2;
      kind = "CapabilityMap";
      name = "Bad hidraw";
      id = "test";
      mapping = [
        {
          name = "Bad";
          source_events = [
            {
              hidraw = {
                report_id = 1;
                input_type = "button";
                byte_start = 0;
                bit_offset = 256;
              };
            }
          ];
          target_event.keyboard = "KeyEnter";
        }
      ];
    }
  ];
in
  assert accepts theatre;
  assert accepts generic;
  assert evaluates theatreSettings;
  assert !accepts invalidDefault;
  assert !accepts invalidName;
  assert !(disabled.environment.etc ? "inputplumber/profiles.d/kodi.yaml");
  assert builtins.elem generic.services.inputplumber.package generic.services.dbus.packages;
  assert builtins.elem generic.services.inputplumber.package generic.services.udev.packages;
  assert builtins.elem pkgs.acl generic.systemd.services.inputplumber.path;
  assert !(builtins.elem disabled.services.inputplumber.package disabled.services.dbus.packages);
  assert !(builtins.elem disabled.services.inputplumber.package disabled.services.udev.packages);
  assert pkgs.lib.all (value: rejects {profiles.test = value;}) badProfiles;
  assert pkgs.lib.all (value: rejects {devices.test = value;}) badDevices;
  assert pkgs.lib.all (value: rejects {capabilityMaps.test = value;}) badMaps;
    pkgs.runCommand "inputplumber-module-tests" {
      nativeBuildInputs = [(pkgs.python3.withPackages (ps: [ps.pyyaml ps.jsonschema]))];
    } ''
      python3 ${./inputplumber.py} \
        ${theatre.systemd.services.inputplumber.environment.XDG_DATA_DIRS}/inputplumber \
        ${generic.systemd.services.inputplumber.environment.XDG_DATA_DIRS}/inputplumber \
        ${pkgs.inputplumber}/share/inputplumber \
        ${pkgs.writeText "theatre-inputplumber.json" (builtins.toJSON theatreSettings)} \
        ${theatre.environment.etc."inputplumber/profiles.d/kodi.yaml".source} \
        ${theatre.environment.etc."inputplumber/profiles.d/game.yaml".source}
      touch "$out"
    ''
