{pkgs}:
pkgs.stdenvNoCC.mkDerivation rec {
  pname = "skiptro";
  version = "1.3.2";

  src = pkgs.fetchurl {
    url = "https://github.com/MikeSiLVO/skiptro-releases/releases/download/v${version}/skiptro-v${version}-linux-x64.tar.gz";
    hash = "sha256-AWiM1BUtOOnfJwDnYSl+g1Lb9vorsqRQgd6+SUtsiZo=";
  };

  sourceRoot = "source";
  unpackPhase = ''
    runHook preUnpack
    mkdir source
    tar --extract --gzip --file "$src" --directory source
    runHook postUnpack
  '';
  nativeBuildInputs = [pkgs.autoPatchelfHook pkgs.makeWrapper];
  buildInputs = [pkgs.stdenv.cc.cc.lib];
  runtimeDependencies = [pkgs.icu pkgs.openssl];
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/skiptro" "$out/bin"
    cp -a . "$out/lib/skiptro/"
    # The CLI hosts its own .NET runtime, detection model and FFmpeg. The tray,
    # browser debugger and optional .NET tracing helper are unused by the service.
    rm -rf "$out/lib/skiptro/BlazorDebugProxy"
    rm -f "$out/lib/skiptro/Skiptro-Desktop"* \
      "$out/lib/skiptro/"Avalonia*.dll \
      "$out/lib/skiptro/HarfBuzzSharp.dll" \
      "$out/lib/skiptro/MicroCom.Runtime.dll" \
      "$out/lib/skiptro/SkiaSharp.dll" \
      "$out/lib/skiptro/Tmds.DBus.Protocol.dll" \
      "$out/lib/skiptro/libHarfBuzzSharp.so" \
      "$out/lib/skiptro/libSkiaSharp.so" \
      "$out/lib/skiptro/createdump" \
      "$out/lib/skiptro/libcoreclrtraceptprovider.so"
    makeWrapper "$out/lib/skiptro/skiptro" "$out/bin/skiptro" \
      --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath [pkgs.icu pkgs.openssl]}" \
      --set DOTNET_ROOT "$out/lib/skiptro" \
      --set DOTNET_CLI_TELEMETRY_OPTOUT 1
    runHook postInstall
  '';

  meta = {
    description = "Local TV intro and credits detection scanner";
    homepage = "https://github.com/MikeSiLVO/skiptro-releases";
    license = pkgs.lib.licenses.unfree;
    platforms = ["x86_64-linux"];
    sourceProvenance = [pkgs.lib.sourceTypes.binaryNativeCode];
    mainProgram = "skiptro";
  };
}
