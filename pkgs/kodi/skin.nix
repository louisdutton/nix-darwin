{pkgs}:
# Forked from Arctic: Zephyr - Reloaded 3.0.3 by jurialmunkey and beatmasterrs.
# https://github.com/beatmasterRS/skin.arctic.zephyr.mod
pkgs.stdenvNoCC.mkDerivation {
  pname = "skin.theatre";
  version = "0.1.0";
  src = ../../config/kodi/skin.theatre;
  nativeBuildInputs = [pkgs.librsvg];
  propagatedBuildInputs = [];
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    target="$out/share/kodi/addons/skin.theatre"
    mkdir -p "$target"
    cp -r . "$target/"
    rsvg-convert "$target/icon.svg" -o "$target/icon.png"
    rsvg-convert "$target/media/localhome/banner-fade.svg" -o "$target/media/localhome/banner-fade.png"
    rsvg-convert "$target/media/localhome/neutral-background.svg" -o "$target/media/localhome/neutral.png"
    rsvg-convert "$target/media/localhome/tab-underline.svg" -o "$target/media/localhome/tab-underline.png"
    rsvg-convert "$target/media/localhome/watch-unwatched.svg" -o "$target/media/localhome/watch-unwatched.png"
    rsvg-convert "$target/media/localhome/game-info-shade.svg" -o "$target/media/localhome/game-info-shade.png"
    rsvg-convert "$target/media/localhome/grid-edge-fade.svg" -o "$target/media/localhome/grid-edge-fade.png"
    # Nintendo Switch L/R glyphs: Kenney Input Prompts 1.5A (CC0).
    # https://kenney.nl/assets/input-prompts
    rsvg-convert "$target/media/localhome/bumper-left.svg" -o "$target/media/localhome/bumper-left.png"
    rsvg-convert "$target/media/localhome/bumper-right.svg" -o "$target/media/localhome/bumper-right.png"
    for source in "$target"/media/localhome/prompt-*.svg; do
      rsvg-convert "$source" -o "''${source%.svg}.png"
    done
    runHook postInstall
  '';
  meta = {
    description = "Local media and gamepad focused Kodi skin";
    license = pkgs.lib.licenses.cc-by-nc-sa-30;
    platforms = pkgs.lib.platforms.linux;
  };
}
