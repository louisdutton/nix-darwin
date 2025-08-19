{pkgs, ...}: {
  # Whisper-cpp dictation setup
  home.packages = with pkgs; [
    whisper-cpp
    sox

    (writeShellScriptBin "dictate" (builtins.readFile ../dictate.sh))
  ];
}
