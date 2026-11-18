# Dictation (Superwhisper)

Omarchy 4.5 uses **Superwhisper** as its default dictation backend, with
**Voxtype** and **Hex** as alternatives. This port now follows that choice and
replaces the former Jarvis assistant with Superwhisper dictation.

## What is installed

Superwhisper's official Linux flake is a Nix input:

```nix
superwhisper.url = "github:superultrainc/superwhisper-linux-releases";
```

The Home Manager module installs:

- the `superwhisper` package (1.3.1, unfree/proprietary);
- the desktop entry and icons;
- the `superwhisper.service` user service (`superwhisper daemon`);
- no update timer: Nix owns updates (`SUPERWHISPER_UPDATE_DISABLED=1`).

`home-manager/modules/desktop/superwhisper-ptt.py` adds Right Alt
push-to-talk. niri 26.04 has neither key-release binds nor the GlobalShortcuts
portal that Superwhisper uses on Hyprland/KDE/GNOME, so the helper reads the
keyboard devices directly (the user is in the `input` group) and calls:

```text
press Right Alt   -> superwhisper record start
release Right Alt -> superwhisper record stop
```

`Alt+Space` is the app-search shortcut in this configuration, so it is not a
dictation toggle. Superwhisper's own shortcut registration is paused
(`superwhisper shortcuts pause on`); the evdev helper owns Right Alt.

### niri-git

nixpkgs unstable still ships niri 26.04, which lacks press/release binds and
the GlobalShortcuts portal. The configuration therefore builds the compositor
from `github:niri-wm/niri` (`inputs.niri-git`) and sets:

```nix
programs.niri.package = inputs.niri-git.packages.${pkgs.stdenv.hostPlatform.system}.niri;
```

After switching and logging into the new niri, the evdev bridge becomes
redundant. Replace it with a native bind and disable
`superwhisper-ptt.service`:

```kdl
Alt_R {
    press { spawn "/etc/profiles/per-user/valen/bin/superwhisper" "record" "start"; }
    release { spawn "/etc/profiles/per-user/valen/bin/superwhisper" "record" "stop"; }
}
```

Until that login, keep the evdev bridge: niri 26.04 rejects the `press {}` /
`release {}` syntax. The XKB `compose:ralt` option was moved to
`compose:menu` so Right Alt is free for dictation; Compose now lives on the
Menu key.

## Configuration

The runtime configuration is in `~/.config/superwhisper/`:

```bash
superwhisper general show
superwhisper general set language '"ru"'
superwhisper models select cloud        # or offline / offline_lite
superwhisper status
superwhisper history list --limit 5
superwhisper settings                   # GUI settings, account/licence
```

Current setup:

- language `ru`;
- cloud processing on the free tier (no account linked);
- cloud transcribed a 5.94 s Russian sample in about 1.1 s with punctuation;
- offline is available by downloading models in Settings. Parakeet TDT 0.6B v3
  (485 MB) covers 25 European languages including Russian; Cohere Transcribe
  (1.5 GB) does **not** include Russian.

The free cloud tier is limited; for long-term use choose offline in Settings or
link a licence. Audio/transcript handling follows Superwhisper's own terms.

## Build and apply

The flake input and Home Manager module are committed, but the running system
still uses the manually started runtime units until the next switch:

```bash
nixos-rebuild switch --flake .#asus-expertbook --option substituters https://cache.nixos.org
```

After the switch, HM installs the package, desktop entry and the same user
services. The runtime units in `~/.config/systemd/user/` are replaced by the
Home Manager generation.

## Tests performed

```bash
superwhisper doctor
superwhisper transcribe /tmp/opencode/stt-long.wav
superwhisper status
```

`doctor` reports every dependency and library as resolved. The Russian sample
was transcribed correctly through the cloud backend; the result is visible in
`superwhisper history list`.
