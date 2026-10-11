{pkgs}: let
  swig = pkgs.swig.overrideAttrs {
    version = "4.5.0";
    src = pkgs.fetchFromGitHub {
      owner = "swig";
      repo = "swig";
      tag = "v4.5.0";
      hash = "sha256-NXN3Zx66PNpYNuFVCalHymb/GW0cUi5drjIXNOVMgb8=";
    };
  };
  # Piers' patched DVD libraries are built internally, with all archives fetched
  # by Nix rather than by CMake during the sandboxed build.
  dvdSources = pkgs.lib.mapAttrs (name: spec:
    pkgs.fetchurl {
      url = "https://mirrors.kodi.tv/build-deps/sources/${name}-${spec.version}.tar.bz2";
      inherit (spec) hash;
    }) {
    libdvdcss = {
      version = "1.5.0";
      hash = "sha512-Q5+9na5guaEU00KaGXA0eMc06FJaxoUtpvBfctnKRMoKxeh0q2oQAX5/MYafzSnwHRvBVsTwMxtOSr2Y7C+VzQ==";
    };
    libdvdread = {
      version = "7.0.1";
      hash = "sha512-tTkKGsuP324kGI+SWRmesP7y3UszJEe6K/pXH5/Aw7+tAMHSeouIBhgKhTwEqBi3gC0wdf94cULBoXWteYxqPQ==";
    };
    libdvdnav = {
      version = "7.0.0";
      hash = "sha512-jRLUduNS3vlxbsvXuhhKcN2brofc3mabhkeg75rBmR9hfJkYwEPhWes1MwLEzFD7cbxZHOrrodO51Hr3f6cscQ==";
    };
  };
  # Remove this override once nixpkgs ships Piers with the PipeWire hotplug
  # and Wayland initial fullscreen fixes.
  # https://github.com/xbmc/xbmc/pull/27615
  core =
    (pkgs.kodi.override {
      waylandSupport = true;
      ffmpeg = pkgs.ffmpeg;
      libcrossguid = pkgs.crossguid;
    }).overrideAttrs (old: {
      version = "22.0rc1";
      kodiReleaseName = "Piers";
      src = pkgs.fetchFromGitHub {
        owner = "xbmc";
        repo = "xbmc";
        tag = "22.0rc1-Piers";
        hash = "sha256-zIQdK3Rj+TLSopJ1R10kEDlHkrgHa36HFN4VszSUJLM=";
      };
      # The nixpkgs GIFLIB patch is already included in this release.
      # Gamescope can initially configure a requested fullscreen surface as
      # windowed. Keep Kodi's mode in sync so it initializes the render size.
      patches = [./wayland-initial-fullscreen.patch];
      buildInputs =
        old.buildInputs
        ++ [
          pkgs.exiv2
          pkgs.nlohmann_json
          pkgs.pcre2
          pkgs.libsysprof-capture
          pkgs.libxcb
        ];
      nativeBuildInputs = old.nativeBuildInputs ++ [pkgs.meson pkgs.ninja swig];
      # meson is only used by the nested DVD builds; Kodi itself uses CMake/Make.
      dontUseMesonConfigure = true;
      dontUseNinjaBuild = true;
      dontUseNinjaInstall = true;
      cmakeFlags =
        builtins.filter (
          flag:
            !pkgs.lib.hasPrefix "-Dlibdvd" flag && !pkgs.lib.hasPrefix "-DSWIG_EXECUTABLE=" flag
        )
        old.cmakeFlags
        ++ [
          "-DSWIG_EXECUTABLE=${swig}/bin/swig"
          "-DENABLE_INTERNAL_FFMPEG=OFF"
          "-DDISABLE_FFMPEG_SOURCE_PLUGINS=ON"
          "-DLIBDVDCSS_URL=${dvdSources.libdvdcss}"
          "-DLIBDVDREAD_URL=${dvdSources.libdvdread}"
          "-DLIBDVDNAV_URL=${dvdSources.libdvdnav}"
        ];
    });
in
  core
