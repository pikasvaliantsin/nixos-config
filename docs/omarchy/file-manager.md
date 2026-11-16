# File manager

The GUI file manager is **Dux Files** (`dev.duxlabs.files`), from the
`dux-files` flake input (`stable-2.1`, currently 2.1.2).

The current stable package runs its QML UI on upstream Quickshell. Newer Dux
Files releases embed **dux-qt-base** (`libdux-qt-base.so.0`), the Dux fork of
the Quickshell runtime; the Home Manager module then exposes
`programs.dux-files.duxQtBase.package` instead of `quickshell.package`. The
integration below does not depend on the runtime: it is still a QML app reading
the DMS colour cache and exposing the same `dfiles` CLI, desktop entry, D-Bus
services and portal backend.

## Opening it

- `Mod+E` toggles the Dux window (`dfiles toggle`). It starts the daemon and
  the UI if they are not running.
- The **Files** entry in the app menu opens `dfiles open`.
- Folder links, `xdg-open <dir>`, and “Open folder” in the print panel go to
  Dux because it is the default `inode/directory` handler.

It is a normal GUI file manager: sidebar places, list/icon views, tabs,
context menus, drag and drop, move/copy, trash, archive and PDF preview.
Files and folders can be dragged onto the pinned folders in the sidebar; the
sidebar bookmarks live in `~/.config/dfiles/bookmarks.json` and currently
include `Documents/Print`.

## Default MIME handlers

`home-manager/modules/desktop/mime-defaults.sh` runs after every Home Manager
activation. It:

- removes the stale `dms-open.desktop` lines left by DankMaterialShell;
- sets `inode/directory`, `x-scheme-handler/file`, `sftp`, `smb` and `trash` to
  `dev.duxlabs.files.desktop`;
- backs up the previous `~/.config/mimeapps.list` once to
  `mimeapps.list.bak-omarchy`.

Check the effective value with both tools, because GTK/GIO and xdg-utils read
the file differently:

```bash
dfiles mime default inode/directory
gio mime inode/directory
xdg-mime query default inode/directory
```

## Theme and fonts

Dux is a separate Quickshell application and does not read
`~/.local/state/theme/current` directly. In `colorSource: "auto"` mode it reads
the DMS cache:

```text
~/.cache/dms/dms-colors.json
~/.cache/dms/dms-typography.json
```

`theme-dms` (from `home-manager/modules/desktop/theme-dms.sh`) generates both
files from the active Omarchy palette and is called by `theme-set` and by Home
Manager activation. It writes the Material-style keys Dux expects, uses
**Inter** for UI text and **JetBrains Mono** for monospace, and keeps
`org.gnome.desktop.interface color-scheme` in sync with the theme's dark/light
mode so Dux's `themeMode: "auto"` follows it.

Dux watches the color file and reloads it. The previous `dms-colors.json` came
from DankMaterialShell (November) and was the reason Dux ignored every later
theme switch.

## Portal

Dux ships an xdg-desktop-portal FileChooser backend and a
`org.freedesktop.FileManager1` service. The FileManager1 service is installed,
so “show in folder” requests can activate Dux. The **file chooser stays GTK**:
`home-manager/modules/desktop/portals.nix` explicitly selects the GTK portal
for niri. Dux's own portal is available but not preferred; enabling it would
make every app's open/save dialog use Dux and should be tested separately.

## Weight

Dux pulls QtWebEngine for PDF/office preview: the closure is about 1.6 GiB,
and the running daemon plus UI use roughly 340 MiB. There is currently no
lighter GUI file manager with a comparable side preview:

- Thunar/Caja are ~0.33 GiB but have no preview pane, only thumbnails;
- Nemo + nemo-preview is ~1.9 GiB and runs through XWayland;
- Nautilus + Sushi is ~2.5 GiB;
- Dolphin + kio-extras is ~1.9 GiB.

Yazi is the lightweight preview option, but it is a TUI; it remains installed
for `Mod+E`-style terminal work if wanted.

## Troubleshooting

- **Folder opens in the wrong app** — run `mime-defaults` (or re-run the Home
  Manager activation) and check `gio mime inode/directory`.
- **Theme did not change in Dux** — run `theme-dms`; the file is
  `~/.cache/dms/dms-colors.json`. Dux must be running with
  `colorSource: "auto"` and `themeMode: "auto"`.
- **No Dux window on `Mod+E`** — `dfiles show` or `dfiles toggle` should open
  it; use `dfiles ipc list` to inspect the running daemon. Inspect
  `journalctl --user -u dfiles` (the service is normally disabled and the
  daemon is started on demand). Newer builds with `dux-qt-base` are embedded in
  `dfiles`; do not look for a separate `quickshell -p dfiles-shell` process
  there.
