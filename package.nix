##
# Package: mpd-voice
# Purpose: Voice control for MPD — one microphone utterance becomes an intent
#   ("next track", "volume 40", "play album …") and is executed against the
#   Music Player Daemon; the confirmation is spoken back through the same local
#   speech stack.
#
# Rust, no crates: the MPD wire protocol, the HTTP speech clients, the OSC-free
# config reader and the intent parser are all std. Speech recognition and
# synthesis stay outside the client — capture goes through pw-record/arecord/
# ffmpeg/sox (or a command template), STT through an OpenAI-compatible endpoint
# or whisper.cpp, TTS through piper or a local tool — because those are
# deployment decisions, not program decisions.
{
  lib,
  rustPlatform,
}:

rustPlatform.buildRustPackage {
  pname = "mpd-voice";
  version = (lib.importTOML ./Cargo.toml).package.version;

  src = ./.;

  cargoLock.lockFile = ./Cargo.lock;

  meta = {
    description = "Voice control for MPD: local speech recognition into player commands";
    homepage = "https://github.com/neg-serg/mpd-voice";
    license = lib.licenses.mit;
    mainProgram = "mpd-voice";
    platforms = lib.platforms.unix;
  };
}
