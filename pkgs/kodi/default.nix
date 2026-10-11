{
  pkgs,
  homeDirectory,
  preview ? false,
}: let
  assets = ../../config/kodi;
  core = import ./core.nix {inherit pkgs;};
  joystick = core.packages.buildKodiBinaryAddon {
    pname = "peripheral.joystick";
    namespace = "peripheral.joystick";
    version = "22.0.11";
    src = pkgs.fetchFromGitHub {
      owner = "xbmc";
      repo = "peripheral.joystick";
      rev = "15e909d54c14aa545cccca449c8fb71743d24395";
      hash = "sha256-usBZdGsNBDE5UXK7JnMEsJm8CSNM03bGCJeFkknTUDY=";
    };
    extraBuildInputs = [pkgs.tinyxml-2 pkgs.udev];
    meta = core.packages.joystick.meta;
  };
  skin = core.packages.toKodiAddon (import ./skin.nix {inherit pkgs;});
  skinId = "skin.theatre";
  selectedAddons = {"skin.theatre" = skin;};
  preferences = import (assets + /preferences.nix);
  mediaSources = [
    {
      path = "${homeDirectory}/Videos/Films/";
      content = "movies";
    }
    {
      path = "${homeDirectory}/Videos/TV Shows/";
      content = "tvshows";
    }
  ];
  localHome = core.packages.buildKodiAddon {
    pname = "localhome";
    namespace = "plugin.program.localhome";
    version = "1.13.0";
    src = assets + /localhome;
    postInstall = ''
      cp ${pkgs.writeText "kodi-launch-tools.json" (builtins.toJSON {
        xprop = "${pkgs.xprop}/bin/xprop";
        xdotool = "${pkgs.xdotool}/bin/xdotool";
        busctl = "${pkgs.systemd}/bin/busctl";
        inputplumber = "${pkgs.inputplumber}/bin/inputplumber";
        umu = "${pkgs.umu-launcher}/bin/umu-run";
        steam-run = "${pkgs.steam-run}/bin/steam-run";
        systemd-run = "${pkgs.systemd}/bin/systemd-run";
        systemctl = "${pkgs.systemd}/bin/systemctl";
        python = "${pkgs.python3}/bin/python3";
        proton = "${pkgs.proton-ge-bin.steamcompattool}";
        gog = "${import ../gog {inherit pkgs;}}/bin/gog";
      })} $out/share/kodi/addons/plugin.program.localhome/launch-tools.json
      cp ${pkgs.writeText "kodi-media-sources.json" (builtins.toJSON mediaSources)} \
        $out/share/kodi/addons/plugin.program.localhome/media-sources.json
      cp ${pkgs.writeText "kodi-game-launches.json" (builtins.toJSON (import (assets + /game-launches.nix) {inherit pkgs;}))} \
        $out/share/kodi/addons/plugin.program.localhome/game-launches.json
    '';
  };
  managedAddons = builtins.attrNames selectedAddons ++ ["plugin.program.localhome"];
  bundledManifest =
    pkgs.runCommand "kodi-addon-manifest.xml" {
      nativeBuildInputs = [pkgs.python3];
      ids = builtins.toJSON managedAddons;
    } ''
      python3 - ${core}/share/kodi/system/addon-manifest.xml "$out" <<'PY'
      import json, os, sys, xml.etree.ElementTree as ET
      tree = ET.parse(sys.argv[1])
      root = tree.getroot()
      for addon in json.loads(os.environ['ids']):
          node = next((n for n in root.findall('addon') if n.text == addon), None)
          if node is None:
              node = ET.SubElement(root, 'addon')
              node.text = addon
          node.attrib.pop('optional', None)
      tree.write(sys.argv[2], encoding='utf-8', xml_declaration=True)
      PY
    '';
  # Explicit pins take precedence over Kodi's bundled scraper versions.
  kodi = (core.withPackages (_: [joystick localHome] ++ map pkgs.lib.hiPrio (builtins.attrValues selectedAddons))).overrideAttrs (old: {
    postBuild =
      (old.postBuild or "")
      + ''
        test -f "$out/share/kodi/addons/${skinId}/addon.xml"
        if test -L "$out/share/kodi/system"; then
          cp -rL "$out/share/kodi/system" kodi-system
          chmod -R u+w kodi-system
          unlink "$out/share/kodi/system"
          mv kodi-system "$out/share/kodi/system"
        fi
        chmod u+w "$out/share/kodi/system"
        rm "$out/share/kodi/system/addon-manifest.xml"
          cp ${bundledManifest} "$out/share/kodi/system/addon-manifest.xml"
          chmod u+w "$out/share/kodi/system/peripherals.xml"
          ${pkgs.python3}/bin/python3 ${./patch_peripherals.py} "$out/share/kodi/system/peripherals.xml"
      '';
  });
  deployment = pkgs.writeText "kodi-deployment.json" (builtins.toJSON {
    inherit managedAddons;
    gui = preferences.gui;
    inherit mediaSources;
    coreVersion = core.version;
    retiredProfilePaths = [
      "addons/skin.arctic.zephyr.mod"
      "userdata/addon_data/skin.arctic.zephyr.mod"
      "userdata/addon_data/script.skinshortcuts"
      "userdata/addon_data/plugin.video.themoviedb.helper"
      "userdata/addon_data/script.embuary.helper"
      "userdata/addon_data/script.litebox"
      "userdata/addon_data/script.module.simplecache"
      ".nix-menu-signature"
    ];
    profileFiles = {
      "userdata/keymaps/local-home-gamepad.xml" = "${assets}/gamepad.xml";
      "userdata/addon_data/peripheral.joystick/resources/buttonmaps/xml/linux/Pro_Controller_14b_6a.xml" = "${assets}/Pro_Controller_14b_6a.xml";
    };
  });
  prepare = pkgs.writeShellScript "prepare-kodi" ''
    ${pkgs.python3}/bin/python3 ${./audio_ready.py} ${pkgs.pipewire}/bin/pw-cli || exit $?
    ${pkgs.python3}/bin/python3 ${./prepare.py} ${deployment}
  '';
  package = pkgs.symlinkJoin {
    name =
      if preview
      then "theatre-kodi-preview"
      else "theatre-kodi";
    paths = [kodi];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      for binary in kodi kodi-standalone; do
        rm "$out/bin/$binary"
        makeWrapper ${pkgs.python3}/bin/python3 "$out/bin/$binary" \
          ${pkgs.lib.optionalString preview "--set-default KODI_DATA '${homeDirectory}/.local/state/kodi-theatre-preview'"} \
          --unset KODI_AE_SINK \
          --add-flags '${./session_owner.py} ${pkgs.systemd}/bin/systemd-run ${pkgs.systemd}/bin/systemctl ${./session_guardian.py} ${kodi}/bin/'"$binary"' --audio-backend=pipewire' \
          --run '${prepare} || exit $?'
      done
    '';
    passthru = {inherit prepare deployment;};
    meta.mainProgram = "kodi";
  };
in {
  inherit package prepare deployment preferences mediaSources core skin;
}
