# Omarchy shell — vendored base

- Upstream: https://github.com/omacom/omarchy
- Tag: `v4.5.0`
- Commit: see `git ls-remote --tags https://github.com/omacom/omarchy.git | grep v4.5.0`
- License: MIT (see `LICENSE`)
- Vendored: 2026-11-13

Only the shell runtime is kept here:

- `shell/` — Quickshell desktop host, bar, panels, services
- `config/omarchy/shell.json` — default layout
- `default/themed/` — theme template assets
- `default/i18n/{en,ru}/` — shell translations
- `bin/` — only the helpers currently used by the base panels

## Local changes

- Niri adapter: `shell/Commons/Niri.qml`, `NiriModel.js`, `shell/plugins/bar/widgets/Workspaces.qml`
- `Style.qml` reads `~/.config/omarchy/niri-style.json` instead of `hyprctl`
- `Bar.qml` uses `Niri.focusedOutput`; Hyprland fullscreen/notch hooks removed
- `shell.qml` does not register Hyprland global shortcuts; niri binds own the keys
- Default layout and disabled plugins are in `config/omarchy/shell.json`
- Notifications, lock, idle, polkit, dock, menu, media, agents, weather and
  other unused upstream plugins are disabled. The clipboard plugin is adapted
  in place; the custom notification center, capture, sudo, reminders and
  OpenCode UI are added under `shell/Custom/`.

## Documentation

Only the runtime tree is vendored. Upstream `AGENTS.md`, `agents/skills/` and
`docs/` are not copied here; the parts relevant to this port are adapted in
[`docs/omarchy/`](../../docs/omarchy/) at the repository root:

- [`shell-dev.md`](../../docs/omarchy/shell-dev.md) — Quickshell work, niri adapter, IPC, panels
- [`visual-verification.md`](../../docs/omarchy/visual-verification.md) — preview shell, screenshots, recordings
- [`motion.md`](../../docs/omarchy/motion.md) — animation rules
- [`theming.md`](../../docs/omarchy/theming.md) — theme-set/theme-install and generated fragments
- [`notifications.md`](../../docs/omarchy/notifications.md) — custom notification center
- [`i18n.md`](../../docs/omarchy/i18n.md) — strings and catalogs
- [`testing.md`](../../docs/omarchy/testing.md) — build and acceptance workflow

The upstream originals can be read from a `v4.5.0` checkout. They frequently
use Arch/Hyprland commands; the adapted versions here use NixOS, niri,
`systemctl --user` and `omarchy-ipc`.

This is a fork, not a tracking dependency. Upstream updates are manual.
