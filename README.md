# mpd-voice

Voice control for MPD. One microphone utterance becomes an intent ("next track", "volume 40", "play
album …") and is executed against the Music Player Daemon; the reply is printed and, when a speech
backend is configured, also spoken.

```
microphone -> [capture + VAD] -> WAV -> [STT] -> phrase
           -> [rule parser] -> [MPD client] -> reply -> [TTS]
```

Rust, no crates: the MPD wire-protocol client, the capture argument builder, the voice-activity
detector, the HTTP speech clients, the JSON writer, the TOML subset reader and the intent parser are
all `std`. Capture, speech recognition and synthesis stay outside the binary because they are
deployment decisions: capture goes through PipeWire/ALSA/FFmpeg/SoX, STT through an
OpenAI-compatible endpoint or whisper.cpp, TTS through an OpenAI-compatible endpoint or a local
command.

## Commands

```console
$ mpd-voice once                       # push-to-talk: one utterance, then exit
$ mpd-voice listen --wake-word music
$ mpd-voice say "next track"           # typed, same pipeline, no audio
$ mpd-voice say "similar tracks"       # queue neighbours of the current track
$ mpd-voice say "play dark music"      # queue tracks by mood (MTG tagger output)
$ mpd-voice say --dry-run "volume 40"  # parse only
$ mpd-voice status [--json]
$ mpd-voice parse "next track"         # show how a phrase parses
$ mpd-voice phrases                    # every supported phrase, both languages
$ mpd-voice doctor                     # MPD, capture, STT and TTS: what works here
```

Exit codes: `0` success, `1` runtime error (MPD, capture, STT), `3` nothing understood — the player
is left untouched.

## Source layout

| File             | Role                                                                                                                                                    |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `src/main.rs`    | entry point; `status`, `doctor`, `parse`, `phrases` and the JSON output                                                                                 |
| `src/cli.rs`     | flags, subcommand dispatch, the `once`/`listen`/`say` pipeline                                                                                          |
| `src/session.rs` | phrase tables per language mapped to controller actions and replies                                                                                     |
| `src/intents.rs` | intent parser: normalized text -> name/value/tag/number                                                                                                |
| `src/mpd.rs`     | MPD protocol client: quoting, `Key: value` replies, `ACK` decoding, command lists, playback/volume/seek/modes/queue/search/playlists                    |
| `src/config.rs`  | defaults, config files, `MPD_*` / `MPD_VOICE_*` environment, flag overlay                                                                              |
| `src/toml.rs`    | the flat `[section]` + scalar TOML subset the config needs                                                                                              |
| `src/audio.rs`   | capture argv (pw-record, arecord, ffmpeg, sox, custom), PCM framing, energy VAD                                                                        |
| `src/stt.rs`     | STT backends: `http` (OpenAI `/v1/audio/transcriptions`), `cli` (whisper-cli), `cmd`, `none`                                                            |
| `src/tts.rs`     | TTS backends: `http` (OpenAI `/v1/audio/speech`), `cmd`, `none`                                                                                        |
| `src/http.rs`    | minimal HTTP client for the speech endpoints: `Content-Length` and chunked replies, multipart upload; no TLS, no redirects                             |
| `src/rex.rs`     | the small regex engine the intent patterns need                                                                                                         |
| `src/json.rs`    | JSON writer                                                                                                                                             |
| `src/song.rs`    | track display helpers (`song_title`, `song_artist`, `duration_to_clock`, `describe`)                                                                   |

## Configuration

Effective config = defaults, then config files, then environment, then flags.

Files, lowest priority first: `$XDG_CONFIG_DIRS/mpd-voice/config.toml`
(default `/etc/xdg/mpd-voice/config.toml`), then `$XDG_CONFIG_HOME/mpd-voice/config.toml`
(default `~/.config/mpd-voice/config.toml`, which wins). `--config FILE` replaces the whole chain.
The file is flat under `[mpd-voice]`; unknown keys and wrong value shapes are ignored.

Environment: `MPD_HOST`, `MPD_PORT`, `MPD_PASSWORD` (the mpc-compatible names), plus
`MPD_VOICE_LANG`, `MPD_VOICE_STT`, `MPD_VOICE_TTS`, `MPD_VOICE_TAGS_FILE`,
`MPD_VOICE_TAGS_EXCLUDE`.

Defaults worth knowing: `language = ru`, `confirm = true`, `volume_step = 5`, `capture = auto`,
`stt = auto` against `http://127.0.0.1:8002`, `tts = auto` against `http://127.0.0.1:8001`,
`similar_cmd = music-similar --json -k 10`, `tags_file = ~/.cache/music-mtg/tags.jsonl`.

## External tools

Nothing is linked in; each backend is a PATH lookup or a command template:

- capture: `pw-record`, `arecord`, `ffmpeg`, `sox`, or `--capture-cmd` (16 kHz mono s16le PCM on
  stdout);
- STT: any OpenAI-compatible transcription endpoint (`--stt-url`), `whisper-cli` from whisper.cpp, or
  `--stt-cmd`;
- TTS: any OpenAI-compatible speech endpoint, a local command (`spd-say`, `espeak-ng`, …), or `none`;
- "similar tracks" and "what is this track" shell out to `music-similar` and `music-describe` (the
  MERT similarity index and the track description cache, configured by `similar_cmd`/`describe_cmd`);
- "play <mood> music" reads MTG tagger output (`tags_file`).

## Build and checks

```console
$ cargo build --release
$ nix build              # packages.<system>.default
$ nix flake check -L     # phrases, parse and a say dry run: no microphone, MPD or STT needed
```

CI runs `cargo fmt --check`, `cargo clippy --all-targets`, `nix build .#default` and
`nix flake check -L` on every push.

## Provenance

The client was ported file for file from a Python implementation (`mpd_voice`); this repository ships
only the Rust one. While both existed, the port was diffed against the Python client on a fake MPD
and stub STT/TTS servers. No Python tree is needed to build, test or run this client.

## Consuming it from a NixOS host

The host flake takes this repository as an input and makes it follow its nixpkgs pin:

```nix
inputs.mpd-voice = {
  url = "github:neg-serg/mpd-voice";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

The host then installs `inputs.mpd-voice.packages.${system}.default` and writes the system-wide
`/etc/xdg/mpd-voice/config.toml` (the user file overrides it key by key).
