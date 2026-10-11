{pkgs}:
pkgs.runCommand "kodi-openbox.xml" {
  nativeBuildInputs = [pkgs.python3];
} ''
  python3 ${./patch_openbox.py} ${pkgs.openbox}/etc/xdg/openbox/rc.xml "$out" \
    '${pkgs.python3}/bin/python3 ${../../config/kodi/localhome/session_home.py} ${pkgs.xprop}/bin/xprop ${pkgs.xdotool}/bin/xdotool'
''
