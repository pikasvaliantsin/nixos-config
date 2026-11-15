# Repository Guide for Agents

This is a NixOS + Home Manager repository for an ASUS ExpertBook running
**niri** and a vendored **Omarchy Quickshell shell**. It is not the Omarchy
Arch Linux repository; commands, paths and compositor APIs below are adapted
to this fork.

Read this file first, then the matching guide under [`docs/omarchy/`](docs/omarchy/).

## Reuse Omarchy first

This repository is a port, not a greenfield desktop. The vendored Quickshell
Omarchy tree is a complete implementation, and most desktop tasks are already
solved there. **Inventing a new component is the last resort.**

Before writing new QML, a helper script, or a service:

1. Search `vendor/omarchy-shell/shell/` and `vendor/omarchy-shell/bin/` for an
   existing implementation (launcher, bar widget, panel, OSD, media, menu,
   notifications, key handling, theming, etc.).
2. Read the matching note in `docs/omarchy/` and the upstream source around
   that module; the original Omarchy is the reference implementation.
3. Prefer porting/backporting the existing module: replace Hyprland with
   `Commons.Niri`, UWSM/Arch paths with NixOS/niri equivalents, and keep the
   upstream structure and names.
4. Only if there is no equivalent, or its architecture conflicts with
   niri/NixOS, write a local component in `shell/Custom/` and record why in
   [`docs/omarchy/upstream-patches.md`](docs/omarchy/upstream-patches.md).

In practice ~95% of tasks should reuse an existing Omarchy solution with a
port/adaptation. A parallel "simpler" reimplementation loses upstream fixes,
theming, IPC contracts and the agent documentation that already exists; it is
a maintenance liability, not a shortcut.

Recent examples: `shell/services/AppLibrary.qml` (launcher backend),
`bin/omarchy-brightness-display-ddc` (DDC helper), the OSD, the media panel and
the bar widgets are ported/backported Omarchy code, not local inventions.

## Source map

- `flake.nix` — inputs, `nixosConfigurations.asus-expertbook`, overlays.
- `hosts/asus-expertbook/` — system configuration, including
  `desktop/niri.nix`, `system/services.nix`, `system/omarchy-sudo.nix`
  (sudo PAM and the graphical auth helper).
- `home-manager/modules/desktop/omarchy.nix` — shell package, user service,
  `omarchy-ipc`, state activation.
- `home-manager/modules/desktop/omarchy/shell.json` — user bar/plugin layout
  (the deployed file is a symlink to this path).
- `home-manager/modules/desktop/themes.nix` — `theme-set`, `theme-install`,
  `bg-cycle` and generated theme state.
- `home-manager/modules/desktop/desktop-tools.nix` — clipboard capture/copy/GC,
  transient terminal helpers, capture/runtime services.
- `home-manager/modules/desktop/default.nix` — desktop module imports and the
  `dsearch` index configuration.
- `home-manager/modules/niri/` — niri config, binds, theme include.
- `vendor/omarchy-shell/` — vendored Omarchy 4.5.0 shell source. QML source of
  truth; the Nix store copy is read-only.
  - `shell/plugins/` — upstream plugins.
  - `shell/Custom/` — our custom QML (notifications, OpenCode, capture,
    reminders, sudo menu, etc.). The clipboard overlay lives in
    `shell/plugins/clipboard/`.
  - `shell/Commons/` — shared singletons, including `Niri.qml`.
  - `bin/` — only the helpers used by this port.
- `pkgs/omarchy-shell/` — the Nix package wrapping the vendored tree.
- `legacy/quickshell/` — old shell, not started.

## Build and apply

Always include the substituter because the local cache endpoint may be down.

```bash
nixos-rebuild build --flake .#asus-expertbook --option substituters https://cache.nixos.org
nixos-rebuild switch --flake .#asus-expertbook --option substituters https://cache.nixos.org
systemctl --user restart omarchy-shell
```

- `nixos-rebuild build` validates Nix evaluation without activating.
- `switch` needs root; do not assume passwordless sudo is enabled.
- QML is not compiled by Nix. A successful build only proves the package
  built, not that the QML loads. Start the shell and read its journal/log.
- The shell package path can be checked with:
  `systemctl --user show omarchy-shell -p ExecStart --value`.

## Shell rules

- Keep exactly one running Omarchy shell. A separate `dankcal-shell`
  Quickshell process is expected for the calendar; do not kill all
  `quickshell` processes and do not start a second Omarchy shell. A second
  bar/notification server confuses focus, layer ordering and
  clipboard/notification state.
- For a preview build, stop `omarchy-shell.service`, run the built
  `omarchy-launch-shell` under `systemd-run --user`, verify, then stop the
  preview and start the service again. Check
  `pgrep -af 'quickshell -p .*omarchy/shell'` before and after.
- The shell loads plugins from the package's `share/omarchy/shell`, not from
  the repository directly. Rebuild the `omarchy-shell` package after QML edits.
- `omarchy-ipc` resolves the running shell by process, so it also reaches a
  preview instance. Prefer it over hard-coded `quickshell ipc -p` paths.
- IPC examples:
  - `omarchy-ipc call shell toggle local.opencode`
  - `omarchy-ipc call shell toggle omarchy.clipboard`
  - `omarchy-ipc call notifications open`
  - `omarchy-ipc call shell listPlugins`
- Use `Commons.Color` and import `qs.Commons as Commons`. Qt 6.12 has a
  `QtQuick.Color` type that shadows unqualified palette references.
- Bar widgets and panels use the injected `bar`, `settings` and (for panels)
  `KeyboardPanel` contracts. New `KeyboardPanel`-based panels should put the
  card in `content: PanelKeyCatcher { ... }` and keep timers, IPC and data
  outside the content.
- Use the upstream `OverlayWindow` for full-screen overlays (the clipboard and
  the notification center use it); a small `PanelWindow` plus a separate
  dismiss layer can produce focus/layer-click surprises.
- Do not poll when a signal, `FileView(watchChanges)`, native Quickshell
  service or IPC push exists. Gate any remaining timer on the panel being
  open, and keep the timer in one shared service, not per monitor.
- Niri-specific APIs live in `shell/Commons/Niri.qml` and
  `NiriModel.js`. Use `niri msg` / `Niri` helpers instead of Hyprland APIs.
  Workspace references for `focus-workspace` are **index or name**, not the
  internal workspace id.
- Widget files contain Nerd Font glyphs. Do not rewrite them wholesale with
  tools that strip multi-byte codepoints; make targeted edits or insert via
  Python `chr(0x...)`.

## Themes

Theme work goes through `theme-set` and `theme-install`; see
[`docs/omarchy/theming.md`](docs/omarchy/theming.md). The active theme is a
symlink under `~/.local/state/theme/current`, and the shell reads
`~/.local/state/omarchy/current/theme/`. Generated fragments include
`colors.toml`, `shell.toml`, `niri.kdl`, GTK CSS, Ghostty/foot and btop.
Do not hand-edit the Nix store; edit the theme source and regenerate.

## Clipboard and notifications

The notification deck is replaced locally; the clipboard is an adapted
first-party plugin. Both are kept enabled in `shell.json`:

- clipboard: `shell/plugins/clipboard/`, `home-manager/modules/desktop/desktop-tools.nix`;
- notifications: `shell/Custom/Notifications.qml`,
  `NotificationCenter.qml`, `NotificationUi.qml`;
- see [`docs/omarchy/notifications.md`](docs/omarchy/notifications.md).

The clipboard capture/copy/GC helpers use
`~/.local/state/quickshell/clipboard/`. Notification history and DND state are
persisted under `~/.local/state/omarchy/notifications/` (`history.json`,
`quiet.json`), mode `0600`; see the notifications notes before changing the
schema.

## Visual verification

Any visual change must be checked in the running UI, not only built. See
[`docs/omarchy/visual-verification.md`](docs/omarchy/visual-verification.md).
Use `grim` for screenshots, `omarchy-capture-screenrecording` for video,
`nix shell nixpkgs#wtype -c wtype ...` for keys, and `niri msg --json` for
compositor state. Record the focused output or a crop when the change is
small. Restore the user's shell after a preview run.

## Commits

- Keep commits atomic and do not commit unrelated user changes.
- Check `git status --short` before staging; the user often has local edits in
  `shell.json`, `hosts/.../services.nix`, `packages.nix`, etc.
- Do not commit secrets, store paths, generated state, screenshots or videos.
- Commit messages follow the existing `feat(area): ...` / `fix(area): ...`
  style.

## Documentation map

Adapted from Omarchy 4.5.0's agent documentation:

- [`docs/omarchy/README.md`](docs/omarchy/README.md) — upstream/adapted map.
- [`shell-dev.md`](docs/omarchy/shell-dev.md) — Quickshell UI work.
- [`visual-verification.md`](docs/omarchy/visual-verification.md) — screenshots,
  recordings, running a preview shell.
- [`motion.md`](docs/omarchy/motion.md) — animation rules.
- [`theming.md`](docs/omarchy/theming.md) — native and Omarchy themes.
- [`notifications.md`](docs/omarchy/notifications.md) — custom notification
  center, history, actions, DND.
- [`launcher.md`](docs/omarchy/launcher.md) — Omarchy menu, dsearch file search
  and the qalc calculator.
- [`auth.md`](docs/omarchy/auth.md) — graphical sudo password/fingerprint
  dialog and the PAM helper.
- [`i18n.md`](docs/omarchy/i18n.md) — shell strings and translation catalogs.
- [`testing.md`](docs/omarchy/testing.md) — build and acceptance workflow.
