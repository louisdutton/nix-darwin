{pkgs}: let
  python = pkgs.python3.withPackages (ps: [ps.requests]);
  downloader = pkgs.writeShellScriptBin "gogdl" ''
    umask 077
    gog_config="''${XDG_CONFIG_HOME:-$HOME/.config}/gog"
    mkdir -p "$gog_config"
    export GOGDL_CONFIG_PATH="$gog_config/gogdl"
    exec ${pkgs.gogdl}/bin/gogdl --auth-config-path "$gog_config/auth.json" "$@"
  '';
  cli = pkgs.writeShellScriptBin "gog" ''
    umask 077
    export PYTHONPATH="${pkgs.gogdl}/${pkgs.python3.sitePackages}''${PYTHONPATH:+:$PYTHONPATH}"
    exec ${python}/bin/python3 ${./gog.py} --gogdl ${downloader}/bin/gogdl "$@"
  '';
in
  pkgs.symlinkJoin {
    name = "gog-tools";
    paths = [downloader cli];
  }
