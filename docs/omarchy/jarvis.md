# Jarvis voice assistant

Jarvis is the push-to-talk voice assistant. It runs as a user service
(`voice-launcher.service`), shows a status icon in the Omarchy bar, and sends
recognised speech to OpenCode. Speech recognition and text-to-speech are local;
the answer model is OpenCode.

The interface and configuration labels stay English. Speech is Russian:
recognition, voice and model replies all use `ru`.

## Hotkeys

| Binding | Action |
|---|---|
| `Ctrl+Shift+J` | Talk to Jarvis (also `Ctrl+Shift+H`). |
| `Ctrl+Shift+K` | Toggle dictation: speak, press again to transcribe and paste into the focused window. |
| `Ctrl+Alt+Shift+J` | Toggle wake-word listening (`hey jarvis`). |

`jarvis talk` starts the service if it is stopped, so the first press works
after a reboot without opening anything.

Wake-word listening is **on** in the shipped config: say `hey jarvis` and talk
after the greeting. The bar icon shows `active`; run `jarvis wake off` to close
the microphone while idle (hotkeys keep working) or `jarvis off` to stop the
whole service during games.

### Why a toggle, not hold-to-talk

niri 26.04 rejects `{ press { ... } release { ... } }` binds (`niri validate`
reports `invalid value`). Hold-to-talk would need niri-unstable/keyd or a
compositor-level key release event. Until then, `Ctrl+Shift+J` toggles the
conversation and `Ctrl+Shift+K` toggles dictation.

## Configuration

User file: `~/.config/jarvis/config.toml`. Only changed keys are written.

```toml
speech_language = "ru"          # STT/TTS/model; language stays "en" (UI)
wake_word_enabled = true
quick_provider = "opencode"
opencode_agent = "plan"
opencode_model = "opencode-go/deepseek-v4.1-flash"
system_access = "off"
agent_session_mode = "legacy"
voice = "ru_RU-dmitri-medium"
voice_length_scale = 1.05
end_silence_seconds = 0.7
stt_provider = "local"
tts_backend = "edge"
edge_voice = "ru-RU-DmitryNeural"
edge_rate = "-6%"
greeting = "Слушаю, сэр."
```

- `quick_provider=opencode` routes quick questions and conversation to
  `opencode run --format json --agent plan`.
- `opencode_model` pins the answering model instead of OpenCode's default
  (`opencode/hy4-flash-free` at the time of writing). Use
  `opencode-go/deepseek-v4.1-flash` for the subscription model.
- `agent_session_mode=legacy` avoids the native Codex/Claude session code,
  which does not know OpenCode.
- `system_access=off` keeps the model knowledge-only. The launcher also forces
  the `off` protocol for the OpenCode command instead of passing a sandbox flag
  OpenCode does not have.
- `opencode_agent=plan` keeps the OpenCode agent read-only. Voice answers do not
  get to run shell commands.
- `speech_language=ru` uses the Russian prompt, Russian TTS voice and Whisper
  language while every configuration label remains English.
- `voice_length_scale` 1.05 keeps Piper close to natural speed; 1.15 (the
  upstream default) sounds stretched. `end_silence_seconds` 0.7 ends the turn
  sooner than the 1.2 default.
- `greeting` is kept short (`Слушаю, сэр.`) and cached, so the wake path does
  not wait for a network TTS request before it starts listening.
- `tts_backend=edge` uses Microsoft's neural `ru-RU-DmitryNeural` through
  `edge-tts`: much better Russian stress and no swallowed syllables than Piper,
  at the cost of internet access and ~1–2 s of synthesis. If the request fails,
  the launcher falls back to the local Piper voice. `edge_rate=-6%` gives the
  calmer, butler-like pacing; a negative `edge_pitch` currently makes edge-tts
  return no audio.
- Fixed phrases (greeting, “Да, сэр?”, “Не расслышал”, “Не понял”, “Готово”)
  are cached in `~/.cache/jarvis/tts` and pre-generated at service start. Edge
  generation retries twice with a 6 s cap, then falls back to Piper, so a slow
  or blocked endpoint cannot hold the answer for long.
- Local Whisper uses `cpu_threads = os.cpu_count()` instead of CTranslate2's
  four-thread default. On this 12-core laptop a 6 s utterance dropped from
  about 5 s to about 3 s of transcription.

Piper remains the offline fallback. The launcher keeps one `PiperVoice` in
memory and synthesizes in-process: the upstream `piper` CLI reloads the 60 MB
ONNX model for every phrase, which adds roughly a second to each reply. Edge
audio goes through `mpv` (no video, no terminal); both players are terminated
by barge-in.

`jarvis config` opens the settings screen; `jarvis config get <key>` and
`jarvis config set <key> <value>` are scriptable.

## Runtime install

Jarvis is a local Omarchy plugin, not a Nix package. The runtime lives outside
this repository:

- plugin: `~/.config/omarchy/plugins/atzingen.jarvis` (upstream `main`, manifest
  2.4.0, commit `40eca12`);
- Python environment: `~/.local/share/jarvis/venv`;
- wrappers: `~/.local/bin/voice-launcher`, `~/.local/bin/jarvis`;
- voices: `~/.local/share/piper-voices` (`ru_RU-dmitri-medium` default;
  `ru_RU-irina-medium` and `ru_RU-ruslan-medium` also installed);
- service drop-in: `~/.config/systemd/user/voice-launcher.service.d/nixos.conf`.

`install.sh` is patched to accept a Nix store `portaudio` instead of
`ldconfig`, and the installed wrappers must use `#!/usr/bin/env bash` (NixOS has
no `/bin/bash`). The venv needs `LD_LIBRARY_PATH` with `portaudio`, `zlib` and
`stdenv.cc.cc.lib`; the drop-in supplies it together with a PATH containing
`opencode`:

```ini
# ~/.config/systemd/user/voice-launcher.service.d/nixos.conf
[Service]
Environment=LD_LIBRARY_PATH=%h/.local/share/jarvis/lib/portaudio/lib:%h/.local/share/jarvis/lib/zlib/lib:%h/.local/share/jarvis/lib/gcc/lib
Environment=PATH=%h/.local/bin:/etc/profiles/per-user/valen/bin:/run/current-system/sw/bin:/usr/bin:/bin
```

Keep the three library paths alive with GC roots:

```bash
mkdir -p ~/.local/share/jarvis/lib
nix build --out-link ~/.local/share/jarvis/lib/portaudio nixpkgs#portaudio
nix build --out-link ~/.local/share/jarvis/lib/zlib nixpkgs#zlib
nix build --out-link ~/.local/share/jarvis/lib/gcc nixpkgs#stdenv.cc.cc.lib
```

Rebuild/reinstall after updating the plugin:

```bash
cd ~/.config/omarchy/plugins/atzingen.jarvis
git apply /path/to/nixos-config/home-manager/modules/desktop/jarvis-patches/local.patch

pa=$(nix eval --raw nixpkgs#portaudio)/lib
zl=$(nix eval --raw nixpkgs#zlib)/lib
cc=$(nix eval --raw nixpkgs#stdenv.cc.cc.lib)/lib
nix shell nixpkgs#python3 nixpkgs#alacritty nixpkgs#wtype nixpkgs#portaudio \
  nixpkgs#pulseaudio nixpkgs#wl-clipboard nixpkgs#curl nixpkgs#libnotify \
  nixpkgs#findutils nixpkgs#gnugrep nixpkgs#zlib nixpkgs#stdenv.cc.cc.lib \
  -c bash -c "export LD_LIBRARY_PATH=$pa:$zl:$cc; bash install.sh --update"
```

The installer only fetches the `pt-BR` and `en-US` voices. Russian voices are
downloaded separately from `rhasspy/piper-voices` (`dmitri` is the default,
`irina` and `ruslan` are alternatives):

```bash
pa=https://huggingface.co/rhasspy/piper-voices/resolve/main/ru/ru_RU
for v in dmitri irina ruslan; do
  for f in "ru_RU-$v-medium.onnx" "ru_RU-$v-medium.onnx.json"; do
    curl -fsSL "$pa/$v/medium/$f" -o "$HOME/.local/share/piper-voices/$f"
  done
done
```

Switch voice without touching anything else:

```bash
jarvis config set voice ru_RU-irina-medium   # or ru_RU-ruslan-medium
systemctl --user restart voice-launcher
```

Expected SHA-256 for the default `dmitri` voice: ONNX
`9ed9941bac7373f2ec1be36627e0e71a349a59ca5522d4363fd50701db05193a`,
JSON `b7ed744f65ec73deb57fc8e419a5db5c0c5532026cf1cd21247f75937b6fbee2`.

After `install.sh`, set both wrappers back to `#!/usr/bin/env bash`:

```bash
sed -i '1s|^#!/bin/bash|#!/usr/bin/env bash|' ~/.local/bin/voice-launcher ~/.local/bin/jarvis
systemctl --user restart voice-launcher.service
```

If the QML was patched *after* `install.sh` (as during the first local
install), sync the installed copy used by the conversation window:

```bash
cp -a ~/.config/omarchy/plugins/atzingen.jarvis/app/qs/. ~/.local/share/jarvis/app/qs/
```

The online neural backend needs `edge-tts` in the Jarvis venv. It is not in the
upstream hash-locked requirements, so install it once (a later
`install.sh --update` leaves extra packages untouched):

```bash
~/.local/share/jarvis/venv/bin/pip install edge-tts
```

`edge-tts` is an unofficial client for Microsoft's free Edge speech endpoint;
audio text leaves the machine. Set `tts_backend = "piper"` to stay offline.

`home-manager/modules/desktop/jarvis-patches/local.patch` contains every local
change: Russian i18n tables and prompt, `speech_language`, OpenCode routing and
event parsing, the knowledge-only command, the in-process Piper voice, the
Edge neural TTS backend with its phrase cache, the Whisper CPU-thread tuning,
the NixOS install check, wrapper shebangs and `Commons.Color` in the QML (Qt
6.12 shadows an unqualified `Color`). Re-apply
it after every upstream update;
conflicts are expected in `jarvis_i18n.py` and `jarvis_config.py`.

## Latency

Measured on this laptop with a game running:

| Stage | Time |
|---|---|
| wake word → listening | ~0.3 s (cached greeting) |
| end-of-speech silence | 0.7 s |
| Whisper small, CPU | ~1–3 s |
| OpenCode (deepseek-v4.1-flash) | ~3–6 s |
| Edge TTS before playback | ~1.5–2 s (fixed phrases are cached) |

So the answer usually starts 6–10 s after the user stops talking. The two
remaining costs are the model round-trip and Edge synthesis. Switching Whisper
to `base` saves roughly 1–2 s at the price of accuracy; a fast cloud STT or a
streaming model answer would cut more.

## Verification

```bash
systemctl --user is-active voice-launcher.service
jarvis status
journalctl --user -u voice-launcher.service -n 40
omarchy-ipc call shell listPlugins | jq '.[] | select(.id=="atzingen.jarvis")'
```

A healthy start logs `config … existe`, `idioma: en | voz:
ru_RU-dmitri-medium`, `tts: edge | edge: ru-RU-DmitryNeural -6%`,
`roteamento: agent | agente: opencode opencode-go/deepseek-v4.1-flash` and
`wake … religada`. The bar widget opens a panel with `LANGUAGE en`, `STT
local`, `AGENT opencode`, `ROUTING agent` and `ACCESS off`.
