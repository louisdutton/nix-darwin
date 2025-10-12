{
  pkgs,
  lib,
  ...
}: let
  # example:
  # ------
  # x86-game ./games/silksong/'Hollow Knight Silksong'
  runner = with pkgs;
    buildFHSEnv {
      name = "x86-game";
      runScript = "box64 \"$@\" -force-opengl";

      profile = ''
        export BOX64_LD_LIBRARY_PATH="${lib.makeLibraryPath (with pkgsCross.gnu64; [
          stdenv.cc.cc.lib
        ])}"
      '';

      targetPkgs = pkgs:
        with pkgs; [
          box64

          # system
          dbus
          zlib
          udev

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

          # debug
          gdb
        ];
    };
in {
  # nintendo pro controller
  boot.kernelModules = ["hid-nintendo"];
  services.udev.packages = with pkgs; [
    game-devices-udev-rules
    dolphin-emu # gamecube/wii emulation
  ];
  hardware.uinput.enable = true;
  hardware.xone.enable = true;

  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [
    runner
    (
      retroarch.withCores (cores:
        with cores; [
          dolphin
          genesis-plus-gx
        ])
    )
  ];
}
