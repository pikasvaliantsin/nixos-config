# Omarchy shell documentation for this port

These notes adapt the agent documentation shipped in
[Omarchy v4.5.0](https://github.com/omacom/omarchy) to this repository:

- NixOS + Home Manager instead of Arch Linux;
- niri instead of Hyprland;
- a vendored shell package (`vendor/omarchy-shell`) instead of
  `$OMARCHY_PATH` from an installed Arch package;
- a locally adapted clipboard plugin and a custom notification center instead
  of the upstream notification deck.

They are deliberately shorter than the upstream files and use commands that
exist in this repository. The upstream originals remain the reference for
Quickshell architecture and general UI rules.

## Reuse before inventing

The vendored shell is the reference implementation, not an empty framework.
Search `vendor/omarchy-shell/shell/` and `vendor/omarchy-shell/bin/` before
writing a new component, and read the matching upstream note. In ~95% of cases
the existing Omarchy module can be ported/backported to niri/NixOS (niri APIs,
NixOS paths, no UWSM). Fresh local code belongs in `shell/Custom/` and must be
justified in [`upstream-patches.md`](upstream-patches.md); a parallel
reimplementation is the last resort.

## Upstream → adapted

| Upstream | Here | What changed |
|---|---|---|
| `AGENTS.md` | [`../../AGENTS.md`](../../AGENTS.md) | NixOS/niri build and runtime rules; repo map; shell service and preview workflow; custom components. |
| `agents/skills/shell-dev.md` | [`shell-dev.md`](shell-dev.md) | Service-based restart, vendored source paths, `omarchy-ipc`, niri event sources, current panel/overlay components. |
| `agents/skills/visual-verification.md` | [`visual-verification.md`](visual-verification.md) | `grim`/`wl-screenrec`, `wtype`, niri JSON commands, preview shell via `systemd-run`, ffmpeg through `nix shell`. |
| `agents/skills/motion.md` | [`motion.md`](motion.md) | Same motion rules; no Hyprland animation toggle, so `Style.reduceMotion` is currently a manual flag. |
| `docs/theming.md` | [`theming.md`](theming.md) | Our `theme-set`/`theme-install`, native palettes, Omarchy `colors.toml`, generated fragments and state links. |
| `docs/notifications.md` | [`notifications.md`](notifications.md) | Our custom server/center: no toasts, persisted history, actions, DND, IPC, known limitations. |
| — | [`file-manager.md`](file-manager.md) | Dux Files: `Mod+E`, MIME defaults, drag/drop books, DMS theme bridge, portal choice and weight. |
| — | [`jarvis.md`](jarvis.md) | Jarvis voice assistant: local STT/TTS, Russian speech, OpenCode answers, hotkeys, runtime patch set and non-declarative install. |
| — | [`printing.md`](printing.md) | Watched print folder, CUPS helper, per-document printed state and reprint flow. |
| — | [`devtools.md`](devtools.md) | Developer toolbox overlay (`Mod+Shift+X`): pure JS engine, secure random pool, native fallbacks for large inputs. |
| — | [`upstream-patches.md`](upstream-patches.md) | Files and hunks to re-apply when bumping the vendored Omarchy tag. |
| — | [`keybindings.md`](keybindings.md) | Searchable keybinding sheet (`Mod+Shift+Slash`), fed from the live niri binds file. |
| `docs/i18n.md` | [`i18n.md`](i18n.md) | Our vendored `en`/`ru` catalogs, `I18n` usage and custom-panel literals. |
| `docs/testing.md` | [`testing.md`](testing.md) | Nix build/switch, QML load checks, clipboard GC and theme tests; no upstream test suite in the vendor. |
| `docs/omarchy-shell.md` | [`shell-dev.md`](shell-dev.md) | Condensed to the parts used by this port. |
| `docs/file-layout.md` | this page | We keep only the runtime tree in `vendor/omarchy-shell`; host/app config is under `home-manager/` and `hosts/`. |
| `shell/plugins/README.md`, `shell/README.md` | `vendor/omarchy-shell/shell/*/README.md` | Kept from upstream; still useful for plugin and bar contracts. |

Upstream paths above refer to the Omarchy source tree, not to this repository.
If you need the full originals, fetch the `v4.5.0` tree from the upstream
repository; `vendor/omarchy-shell/UPSTREAM.md` records the vendored tag.

## Reading order

1. [`../../AGENTS.md`](../../AGENTS.md) — repository rules.
2. [`shell-dev.md`](shell-dev.md) — before touching QML.
3. [`visual-verification.md`](visual-verification.md) — before finishing any
   visual change.
4. [`motion.md`](motion.md) — before adding or changing animation.
5. Area notes: [theming](theming.md), [notifications](notifications.md),
   [devtools](devtools.md), [launcher](launcher.md), [auth](auth.md),
   [i18n](i18n.md), [testing](testing.md), [keybindings](keybindings.md),
   [printing](printing.md), [file manager](file-manager.md),
   [Jarvis voice assistant](jarvis.md),
   [upstream patches](upstream-patches.md).

## Deliberate differences from upstream

- The shell is a Nix package. You cannot patch the running store path; edit
  `vendor/omarchy-shell`, rebuild, and restart the service.
- `omarchy-restart-shell` is replaced by `systemctl --user restart
  omarchy-shell`.
- `omarchy-shell` IPC is exposed through `omarchy-ipc`, which finds the
  actually running shell process.
- Hyprland calls are replaced by niri calls under `shell/Commons/Niri.qml`.
- Screenshot/recording helpers are the ones packaged in this repo
  (`omarchy-capture-screenshot`, `omarchy-capture-screenrecording`, `grim`,
  `wl-screenrec`), not the upstream `omarchy capture` CLI.
- The notification center, clipboard and developer toolbox are local code:
  the center lives in `shell/Custom`, the clipboard plugin in
  `shell/plugins/clipboard`, the toolbox in `shell/Custom/DevTools*`; see
  their notes before changing behaviour.
