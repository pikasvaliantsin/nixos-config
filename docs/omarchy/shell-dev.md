# Quickshell shell development

Read this before editing anything under `vendor/omarchy-shell/shell/`.

## Source and runtime

- Source of truth: `vendor/omarchy-shell/shell/`.
- Nix package: `pkgs/omarchy-shell/default.nix`; built shell lives in the Nix
  store and is read-only.
- User service: `omarchy-shell.service` (Home Manager module
  `home-manager/modules/desktop/omarchy.nix`).
- Launcher: `omarchy-launch-shell`, which runs
  `quickshell -p "$OMARCHY_PATH/shell"` with `OMARCHY_PATH` pointing at the
  package's `share/omarchy` tree.
- IPC: `omarchy-ipc` from the same Home Manager module. It resolves the
  running shell by process, so it works with both the service and a preview
  instance.

Do not leave multiple Omarchy shell instances running. A second instance
creates a second bar, a second notification server and competing layer
surfaces. The separate `dankcal-shell` Quickshell process is expected; check
only the Omarchy shell:

```bash
pgrep -af 'quickshell -p .*omarchy/shell'
systemctl --user is-active omarchy-shell
```

For a preview build, stop the service, run the built package under
`systemd-run --user --unit=omarchy-shell-test --collect`, verify, stop the
preview, then start the service. See
[`visual-verification.md`](visual-verification.md).

## Plugin contract

- First-party plugins live under `shell/plugins/`, one category level deep for
  panels (`shell/plugins/panels/<name>/`) and the clipboard
  (`shell/plugins/clipboard/`).
- Third-party plugins belong in `~/.config/omarchy/plugins/<id>/` with a
  `manifest.json` at the root.
- A manifest declares `schemaVersion`, `id`, `name`, `version`, `kinds` and
  `entryPoints`.
- Entry QML files are `Item`s. They receive `omarchyPath`, `shell`,
  `manifest`, and the applicable registry/capability objects.
- Panel/overlay/menu plugins expose `open(payloadJson)` and `close()` for
  `omarchy-ipc call shell summon|hide|toggle`.
- Upstream recommends that a `KeyboardPanel` pass its card in
  `content: PanelKeyCatcher { ... }` so content is built on first open. Some
  existing `shell/Custom` panels still use direct children; follow the local
  component's current shape, and prefer the `PanelKeyCatcher` form when adding
  or refactoring a panel.
- Our local components live in `shell/Custom/` and are exposed through
  `qs.Custom` (`Custom/qmldir`). A new QML component must be added there to be
  importable by `qs.Custom`.

## IPC

`omarchy-ipc` forwards to the running shell. It does not start one.

Useful calls:

```bash
omarchy-ipc call shell ping
omarchy-ipc call shell summon omarchy.clipboard '{}'
omarchy-ipc call shell toggle local.opencode
omarchy-ipc call shell listPlugins
omarchy-ipc call notifications open
omarchy-ipc call shell reloadConfig
```

Plugin targets are named after the plugin, not the place it appears. Bar
widgets have their own target where needed (`omarchy.indicators`,
`omarchy.clock`, `omarchy.power`, ...). There is no generic `bar` target.

## Keeping state current

The shell runs all day and each bar widget is instantiated per monitor. Avoid
timers that spawn a process per monitor.

Prefer, in order:

1. A native Quickshell service with change signals: `UPower`, `Pipewire`,
   `Mpris`, `SystemTray`, `Notifications`.
2. The existing niri event stream in `shell/Commons/Niri.qml`
   (`niri msg --json event-stream`). Extend `NiriModel.js` instead of opening a
   second stream.
3. `FileView { watchChanges: true }` for files the user or a helper writes.
4. A push from the command that changes state, through `omarchy-ipc`.
5. For state that changes while no command runs (timers, expiry), a transient
   `systemd-run --user --on-active=...` timer that calls `omarchy-ipc`.
6. Polling only when nothing above exists; gate it on the panel being open and
   keep one shared poller.

Never poll a privileged probe. `sudo -n` writes to the auth log.

## Niri specifics

- Use `shell/Commons/Niri.qml` and `NiriModel.js`, not Hyprland.
- `niri msg action focus-workspace <reference>` takes an **index or name**, not
  the internal workspace id from `niri msg --json workspaces` (`id` values are
  global and non-contiguous).
- Workspace lists are sorted by `idx` in `NiriModel.workspaceItems`.
- For layer-shell surfaces prefer the upstream `OverlayWindow` (as the
  clipboard and notification center do) or `KeyboardPanel` (as bar popups do).
  A `PanelWindow` plus a separate dismiss layer can introduce focus/click
  ordering problems.
- Niri has no Hyprland animation toggle; `Style.reduceMotion` exists but is not
  currently wired to a niri setting.

## Glyphs and icons

Bar widget files can contain Nerd Font codepoints. Do not rewrite them
wholesale with tools that can strip multi-byte characters. Make a targeted
edit with surrounding context, or insert with Python `chr(0x...)`.

For vector/brand icons, use the existing `Image`/`sourceSize` pattern (see the
OpenCode bar widget) or `OpticalGlyph`; do not introduce a second icon loader.

## Palette and typography

- Import `qs.Commons as Commons` and use `Commons.Color` for palette tokens.
  Qt 6.12's `QtQuick.Color` can shadow unqualified references.
- Keep the unqualified `qs.Commons` import when the file also uses `Style`,
  `Util` or `Border`.
- Sizes go through `Style.space()` / `Style.font.*`; animations go through
  `Style.duration()`.

## Current local components

- `shell/Custom/Notifications.qml` — notification server singleton;
- `NotificationCenter.qml`, `NotificationUi.qml` — center and IPC;
- `shell/plugins/clipboard/` — clipboard overlay and history UI;
- `CaptureMenu.qml`, `ReminderMenu.qml`, `SudoMenu.qml`, `OpenCodePanel.qml`
  — local panels;
- `AuthAgent.qml` — graphical sudo password/fingerprint dialog;
- `shell/Commons/Niri.qml` — niri adapter;
- `home-manager/modules/desktop/themes.nix` — theme generation and switching.
