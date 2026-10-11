{pkgs}:
pkgs.writeShellApplication {
  name = "tv";
  runtimeInputs = [pkgs.libcec pkgs.coreutils];
  text = ''
    case "''${1:-help}" in
      help|--help|-h)
        echo 'Usage: tv on|off|status|cycle|adapters'
        echo 'CEC standby/wake control; requires a supported HDMI-CEC adapter.'
        exit 0
        ;;
      on|off|status|cycle|adapters) ;;
      *) echo 'Unknown TV action; use tv --help.' >&2; exit 2 ;;
    esac
    if [ "$1" = adapters ]; then
      exec timeout 10 cec-client -l
    fi
    adapters=$(timeout 10 cec-client -l)
    if [[ "$adapters" == *'Found devices: NONE'* ]]; then
      echo 'No HDMI-CEC adapter detected. HDMI video support alone is not enough.' >&2
      exit 1
    fi
    # Use one client per action; Kodi must not concurrently own this adapter.
    send() { printf '%s\n' "$@" | timeout 20 cec-client -s -d 1 -t p; }
    case "$1" in
      on) send 'on 0' 'as' ;;
      off) send 'standby 0' ;;
      status) send 'pow 0' ;;
      cycle)
        send 'standby 0'
        sleep 5
        send 'on 0' 'as'
        ;;
    esac
  '';
}
