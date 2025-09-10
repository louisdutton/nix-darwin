{pkgs, ...}: let
  # example:
  # ------
  # x86-game ./games/silksong/'Hollow Knight Silksong'
  runner = with pkgs;
    buildFHSEnv {
      name = "x86-game";
      runScript = "box64 \"$@\" -force-opengl";

      profile = ''
        export BOX64_LD_LIBRARY_PATH="${lib.makeLibraryPath [pkgsCross.gnu64.stdenv.cc.cc.lib]}"
      '';

      targetPkgs = pkgs:
        with pkgs; [
          box64

          # system
          dbus
          udev
          zlib

          # graphics
          libGL

          # x11
          xorg.libX11
          xorg.libXi
          xorg.libXxf86vm
          xorg.libXinerama
          xorg.libXext
          xorg.libXcursor
          xorg.libXrender
          xorg.libXfixes
          xorg.libXrandr
          xorg.libXScrnSaver
          xorg.libxcb
          xorg.libXau
          xorg.libXdmcp

          # wayland
          wayland
          libxkbcommon

          # audio
          alsa-lib
          pulseaudio
        ];
    };
in {
  environment.systemPackages = [
    runner
  ];
}
