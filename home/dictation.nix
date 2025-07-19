{pkgs, ...}: {
  # Whisper-cpp dictation setup
  home.packages = with pkgs; [
    whisper-cpp
    sox

    (writeShellScriptBin "dictate" ''
      MODEL="base.en"
      MODEL_DIR="$HOME/.local/share/whisper-models"
      MODEL_NAME="ggml-$MODEL.bin"
      AUDIO_FILE="/tmp/dictation_$(date +%s).wav"
      TIMEOUT=1.0

      # download model if it doesn't exist
      mkdir -p "$MODEL_DIR"
      if [ ! -f "$MODEL_DIR/$MODEL_NAME" ]; then
        whisper-cpp-download-ggml-model $MODEL $MODEL_DIR
      fi

      # record
      echo "Recording... (will stop after $TIMEOUT seconds of silence)" >&2
      sox -t coreaudio -d                     \
        -r 16000 -c 1 -e signed-integer -b 16 \
        "$AUDIO_FILE"                         \
        silence 1 0.01 0.1% 1 $TIMEOUT 1%     \
        pad 1.0 1.0 2>/dev/null

      if [ ! -s "$AUDIO_FILE" ]; then
        echo "Error: No audio recorded or file is empty" >&2
        exit 1
      fi

      # transcribe and type the output
      transcribed_text=$(whisper-cli \
        -m "$MODEL_DIR/$MODEL_NAME" \
        -f "$AUDIO_FILE"            \
        --no-timestamps             \
        2>/dev/null \
      | xargs -0)

      osascript -e "tell application \"System Events\" to keystroke \"$transcribed_text\""

      # clean up
      rm -f "$AUDIO_FILE"
    '')
  ];
}
