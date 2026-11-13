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
- Notifications, lock, idle, polkit, dock, menu, audio and other unused
  upstream plugins are disabled. Custom notification center, capture and
  OpenCode panel are added separately under `shell/custom/` later.

This is a fork, not a tracking dependency. Upstream updates are manual.
