{
  config,
  pkgs,
  ...
}: let
  zellijBattery = pkgs.writeShellScriptBin "zellij-battery" ''
    for battery in /sys/class/power_supply/BAT*; do
      [ -r "$battery/capacity" ] || continue

      percentage="$(${pkgs.coreutils}/bin/cat "$battery/capacity")"
      status="$(${pkgs.coreutils}/bin/cat "$battery/status")"

      case "$status" in
        Charging) printf 'BAT+ %s%%' "$percentage" ;;
        Full) printf 'BAT= %s%%' "$percentage" ;;
        *) printf 'BAT %s%%' "$percentage" ;;
      esac

      exit 0
    done
  '';
in {
  programs.zellij.enable = true;

  home.packages = [zellijBattery];

  xdg.configFile."zellij".source =
    config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/projects/nixos/config/zellij";

  xdg.dataFile."zellij/plugins/zjstatus.wasm".source =
    pkgs.zellijPlugins.zjstatus;
}
