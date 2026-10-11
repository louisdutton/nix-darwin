{
  pkgs,
  kodi,
  vulkanDevice ? null,
}: let
  hotkey = pkgs.stdenv.mkDerivation {
    pname = "theatre-session-hotkey";
    version = "1";
    dontUnpack = true;
    nativeBuildInputs = [pkgs.pkg-config pkgs.wayland-scanner];
    buildInputs = [pkgs.wayland];
    buildPhase = ''
      protocol=${pkgs.gamescope.src}/protocol/gamescope-action-binding.xml
      wayland-scanner client-header "$protocol" gamescope-action-binding-client-protocol.h
      wayland-scanner private-code "$protocol" gamescope-action-binding-protocol.c
      $CC -std=c11 -Wall -Wextra -Werror -I. ${./session_hotkey.c} \
        gamescope-action-binding-protocol.c $(pkg-config --cflags --libs wayland-client) \
        -o theatre-session-hotkey
    '';
    installPhase = ''
      install -Dm755 theatre-session-hotkey $out/bin/theatre-session-hotkey
    '';
  };
  client = pkgs.writeShellScript "theatre-wayland-client" ''
    export THEATRE_COMPOSITOR=gamescope
    rm -f "$XDG_RUNTIME_DIR/kodi-localhome-game.json"
    ${pkgs.xprop}/bin/xprop -root -f GAMESCOPECTRL_BASELAYER_APPID 32c \
      -set GAMESCOPECTRL_BASELAYER_APPID 1000000001
    ${hotkey}/bin/theatre-session-hotkey \
      ${pkgs.python3}/bin/python3 ${../../config/kodi/localhome/session_home.py} \
      ${pkgs.xprop}/bin/xprop ${pkgs.xdotool}/bin/xdotool &
    shortcutPID=$!
    trap 'kill "$shortcutPID" 2>/dev/null || true' EXIT
    ${kodi}/bin/kodi --standalone --windowing=wayland -fs
  '';
  session = pkgs.writeShellScript "theatre-gamescope" ''
    # SDDM's greeter is a separate compositor; start our own DRM session.
    unset DISPLAY WAYLAND_DISPLAY GAMESCOPE_WAYLAND_DISPLAY
    export XDG_SESSION_TYPE=wayland
    export XDG_CURRENT_DESKTOP=gamescope
    # The application focus API uses Gamescope's Steam-compatible mode;
    # Kodi remains the shell and no Steam client is started.
    exec ${pkgs.gamescope}/bin/gamescope --backend drm --expose-wayland -e \
      ${pkgs.lib.optionalString (vulkanDevice != null) "--prefer-vk-device ${pkgs.lib.escapeShellArg vulkanDevice}"} \
      -w 3840 -h 2160 -r 60 -- ${client}
  '';
in
  pkgs.runCommand "theatre-gamescope-session" {
    passthru.providedSessions = ["theatre-gamescope"];
  } ''
    mkdir -p $out/share/wayland-sessions
    cat > $out/share/wayland-sessions/theatre-gamescope.desktop <<EOF
    [Desktop Entry]
    Name=Theatre
    Comment=Kodi and games in Gamescope
    Exec=${session}
    Type=Application
    DesktopNames=gamescope
    EOF
  ''
