{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.skiptro;
  stateDirectory = "/var/lib/skiptro";
  searchPolicy = pkgs.writeText "skiptro-search-windows.json" (builtins.toJSON cfg.searchWindows);
  # Unit directives need their own quoting for paths such as "TV Shows".
  unitPaths = map (path: builtins.toJSON (lib.replaceStrings ["%"] ["%%"] path)) cfg.libraries;
  cli = pkgs.writeShellScriptBin "skiptro" ''
    export XDG_CONFIG_HOME=${lib.escapeShellArg stateDirectory}
    if ! test -d "$XDG_CONFIG_HOME"; then
      echo "Skiptro state is not initialized yet; wait for skiptro-scan.service." >&2
      exit 1
    fi
    exec ${lib.getExe cfg.package} "$@"
  '';
in {
  options.services.skiptro = {
    enable = lib.mkEnableOption "scheduled Skiptro intro detection and Kodi EDL export";
    package = lib.mkOption {
      type = lib.types.package;
      default = import ../pkgs/skiptro {inherit pkgs;};
      description = "Skiptro scanner package.";
    };
    user = lib.mkOption {
      type = lib.types.str;
      description = "Existing user with read and write access to the TV libraries.";
    };
    libraries = lib.mkOption {
      type = lib.types.listOf (lib.types.strMatching "/.+");
      default = [];
      description = "Absolute TV library paths. EDL sidecars are written beside each episode.";
    };
    searchWindows = lib.mkOption {
      type = lib.types.attrsOf (lib.types.ints.between 1 90);
      default = {};
      description = "Per-show search windows in minutes, keyed by absolute show directory. Limit short episodes so credits cannot be mistaken for intros.";
    };
    onCalendar = lib.mkOption {
      type = lib.types.str;
      default = "*-*-* 03:00:00";
      description = "Systemd calendar for incremental scans.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.libraries != [];
        message = "services.skiptro.libraries must contain at least one TV library.";
      }
      {
        assertion = builtins.hasAttr cfg.user config.users.users;
        message = "services.skiptro.user must name an existing user.";
      }
      {
        assertion = lib.all (lib.hasPrefix "/") (builtins.attrNames cfg.searchWindows);
        message = "services.skiptro.searchWindows keys must be absolute show directories.";
      }
    ];

    # Interactive commands and the scheduled job share the same detection cache.
    environment.systemPackages = [cli];

    systemd.services.skiptro-scan = {
      description = "Detect TV intros and export Kodi EDL files";
      unitConfig.RequiresMountsFor = unitPaths;
      environment.XDG_CONFIG_HOME = stateDirectory;
      script =
        ''
          force=()
          if ! ${pkgs.diffutils}/bin/cmp -s ${searchPolicy} search-windows.json; then
            # The CLI can only configure discovered shows. Bootstrap new shows
            # without exporting, then apply windows and replace those detections.
            ${lib.optionalString (cfg.searchWindows != {}) (lib.concatMapStringsSep "\n" (path: "${lib.getExe cfg.package} scan ${lib.escapeShellArg "${lib.removeSuffix "/" path}/"}") cfg.libraries)}
            # Skiptro does not invalidate cached detections when windows change.
            # Reset previously managed overrides, then rescan with the new policy.
            if test -f search-windows.json; then
              while IFS= read -r show; do
                ${lib.getExe cfg.package} show window "$show" default
              done < <(${pkgs.jq}/bin/jq -r 'keys[]' search-windows.json)
            fi
            force=(--force)
          fi
        ''
        + lib.concatStringsSep "\n" (lib.mapAttrsToList (path: minutes: "${lib.getExe cfg.package} show window ${lib.escapeShellArg path} ${toString minutes}") cfg.searchWindows)
        + "\n"
        + lib.concatMapStringsSep "\n" (path: let
          # Skiptro's export filter is a string prefix: retain the separator so a
          # library called TV cannot also match a sibling called TV-Other.
          root = lib.escapeShellArg "${lib.removeSuffix "/" path}/";
        in ''
          ${lib.getExe cfg.package} scan ${root} "''${force[@]}"
          ${lib.getExe cfg.package} export-edl ${root}
        '')
        cfg.libraries
        + ''
          cp ${searchPolicy} search-windows.json.tmp
          mv search-windows.json.tmp search-windows.json
        '';
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        StateDirectory = "skiptro";
        StateDirectoryMode = "0750";
        WorkingDirectory = stateDirectory;
        UMask = "0022";
        TimeoutStartSec = "infinity";
        Nice = 19;
        IOSchedulingClass = "idle";
        CPUWeight = 10;
        IOWeight = 10;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        ReadWritePaths = unitPaths;
      };
    };

    systemd.timers.skiptro-scan = {
      wantedBy = ["timers.target"];
      # Apply changed libraries, detection policy or scanner versions promptly.
      restartTriggers = [config.systemd.services.skiptro-scan.script];
      timerConfig = {
        OnActiveSec = "1min";
        OnCalendar = cfg.onCalendar;
        Persistent = true;
      };
    };
  };
}
