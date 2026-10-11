{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.inputplumber;
  yaml = pkgs.formats.yaml {};
  configurationTypes = import ./inputplumber/types.nix {
    inherit lib;
    yamlValue = yaml.type;
  };
  validName = name: builtins.match "[A-Za-z0-9_-][A-Za-z0-9_.-]*" name != null;
  generate = kind: name: settings: yaml.generate "inputplumber-${kind}-${name}.yaml" (configurationTypes.omitNulls settings);
  devices = lib.mapAttrs (generate "CompositeDevice") cfg.devices;
  profiles = lib.mapAttrs (generate "DeviceProfile") cfg.profiles;
  capabilityMaps = lib.mapAttrs (generate "CapabilityMap") cfg.capabilityMaps;
  install = directory: files:
    lib.concatStringsSep "\n" (lib.mapAttrsToList (name: file: ''
        rm -f "$out/share/inputplumber/${directory}/${name}.yaml"
        ln -s ${file} "$out/share/inputplumber/${directory}/${name}.yaml"
      '')
      files);
  data = pkgs.runCommand "inputplumber-config" {} ''
    mkdir -p "$out/share/inputplumber"
    cp -rs ${cfg.package}/share/inputplumber/. "$out/share/inputplumber"
    find "$out/share/inputplumber" -type d -exec chmod u+w {} +
    ${lib.optionalString (!cfg.useBundledDeviceConfigs) ''
      rm -rf "$out/share/inputplumber/devices"
    ''}
    mkdir -p "$out/share/inputplumber/"{devices,profiles,capability_maps}
    ${install "devices" devices}
    ${install "profiles" profiles}
    ${install "capability_maps" capabilityMaps}
    ${lib.optionalString (cfg.defaultProfile != null && builtins.hasAttr cfg.defaultProfile profiles) ''
      rm -f "$out/share/inputplumber/profiles/default.yaml"
      ln -s ${profiles.${cfg.defaultProfile}} "$out/share/inputplumber/profiles/default.yaml"
    ''}
  '';
in {
  # Extend nixpkgs' existing module, which supplies enable, package and the service.
  options.services.inputplumber = {
    devices = lib.mkOption {
      type = lib.types.attrsOf configurationTypes.device;
      default = {};
      description = ''
        Named composite device configurations. Each attribute set is generated
        as YAML, with typed options based on InputPlumber's v1 schema.
        Names are filenames without the .yaml extension. Matching devices must
        explicitly opt into capture through options.auto_manage.
      '';
    };
    profiles = lib.mkOption {
      type = lib.types.attrsOf configurationTypes.profile;
      default = {};
      description = ''
        Named device profiles, checked during Nix evaluation and generated as YAML. Profiles
        are available in /etc/inputplumber/profiles.d/NAME.yaml for runtime loading.
      '';
    };
    capabilityMaps = lib.mkOption {
      type = lib.types.attrsOf configurationTypes.capabilityMap;
      default = {};
      description = ''
        Named v1 or v2 capability maps (version defaults to 1), checked during Nix evaluation and generated as YAML. Custom
        files replace bundled capability maps with the same filename.
      '';
    };
    defaultProfile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Name of a declared profile to use as the daemon's default.yaml.
        Null retains the bundled default profile.
      '';
    };
    useBundledDeviceConfigs = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Include InputPlumber's bundled device definitions alongside custom ones.
        Disable this to restrict automatic capture to declared devices. Bundled
        profiles and capability maps remain available.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # InputPlumber uses setfacl to hide captured physical devices from clients.
    systemd.services.inputplumber.path = [pkgs.acl];
    services.dbus.packages = [cfg.package];
    services.udev.packages = [cfg.package];
    assertions = [
      {
        assertion = lib.all validName (builtins.attrNames cfg.devices ++ builtins.attrNames cfg.profiles ++ builtins.attrNames cfg.capabilityMaps);
        message = "InputPlumber configuration names must be safe filenames without directory separators.";
      }
      {
        assertion = cfg.defaultProfile == null || builtins.hasAttr cfg.defaultProfile cfg.profiles;
        message = "services.inputplumber.defaultProfile must name a profile declared in services.inputplumber.profiles.";
      }
    ];
    # InputPlumber picks one XDG data directory; construct a complete merged tree.
    # This overrides the upstream default while still allowing host overrides.
    systemd.services.inputplumber.environment.XDG_DATA_DIRS = lib.mkOverride 90 "${data}/share";
    environment.etc = lib.mapAttrs' (name: source: lib.nameValuePair "inputplumber/profiles.d/${name}.yaml" {inherit source;}) profiles;
  };
}
