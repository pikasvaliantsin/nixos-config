# Upstream update checklist

The shell is a vendored copy of Omarchy v4.5.0 (`vendor/omarchy-shell`,
tag/commit in `UPSTREAM.md`) with local patches on top. This file lists what
a new upstream tag must not silently overwrite.

## Our files (no upstream conflict)

These are new files; a wholesale vendor replacement should keep them:

| Path | Purpose |
|---|---|
| `shell/Custom/GalleryPanel.qml` | theme/wallpaper deck (`Mod+Alt+T`, `Mod+Shift+B`) |
| `shell/Custom/KeybindsPanel.qml` | searchable keybinding sheet (`Mod+Shift+Slash`) |
| `shell/Custom/DevTools.js`, `DevToolsPanel.qml` | developer toolbox (`Mod+Shift+X`) |
| `shell/Custom/Notifications.qml`, `NotificationCenter.qml`, `NotificationUi.qml`, `Toasts.qml` | notification server and center |
| `shell/plugins/bar/widgets/Cava.qml`, `Cava.manifest.json` | cava spectrum |
| `shell/plugins/port-forward/*` | vendored plugin, disabled |
| `bin/omarchy-tray` | hidden-tray helper |
| `shell/Custom/Calc.qml`, `FileSearch.qml`, `KeyboardOsd.qml`, `Idle.qml`, `NightLight.qml`, `AuthAgent.qml` | port-specific panels and services (qalc, dsearch, OSD, lock/idle, auth) |

`shell/Custom/qmldir` and the `shell.qml` instantiation list are patched, not
new; both must mention the files above.

## Patched upstream files

Re-check each against the new tag; the descriptions say what to keep.

- `shell/Ui/KeyboardPanel.qml`
  - freeze the card anchor while open (`freezeAnchor`/`frozenAnchor`);
  - keep `WlrKeyboardFocus.Exclusive` while open;
  - forward a bar click to the widget under the pointer so one click switches
    panels;
  - surface-level `Shortcut` for Escape (content focus can be lost);
  - our `Keys`/dismiss flow assumes the `mask` keeps the bar strip
    click-through.
- `shell/Ui/BarIndicator.qml`, `shell/plugins/bar/widgets/Indicators.qml`,
  `shell/plugins/bar/indicators/ScreenRecording.qml`
  - the recording indicator is hover-revealed, never permanently visible.
- `shell/plugins/bar/widgets/Tray.qml`, `shell/plugins/menu/Menu.qml`
  - app menu footer has Pin/Unpin and Hide;
  - the menu has a hidden-tray provider for `System → Tray icons`.
- `shell/plugins/bar/widgets/OpenCode.qml`
  - the bar mark is drawn in the bar foreground (frame plus a dimmed lower
    block) instead of loading the cream-white `agents/assets/opencode.svg`
    tile, which read as a bright block on a themed bar;
  - keep the upstream SVG geometry (240x300 frame, 60 thick, 120x120 block).
- `shell/plugins/panels/audio/Panel.qml`
  - pressing the icon while the popup is open closes it (right click only
    mutes while closed).
- `shell/plugins/panels/weather/BarWidget.qml`
  - the pill shows `label + temperature` from the panel, not the glyph alone.
- `shell/plugins/services/media/BarWidget.qml`
  - popup is a `KeyboardPanel` (Escape/outside click);
  - LMB opens, RMB play/pause, middle next, wheel changes the player volume
    (MPRIS first, then the player's PipeWire stream, then the default sink);
  - `opened/open/close/toggle` so `shell toggle omarchy.media` works;
  - Output row moves only the player's stream via `pactl move-sink-input`;
  - IPC `omarchy.media` with `volumeUp/Down/Status`, `outputs`, `refresh`,
    `move`.
- `bin/omarchy-brightness-display`
  - shows our OSD instead of swayosd and prefers the internal panel even when
    an external monitor is focused.
- `bin/omarchy-brightness-display-ddc` (backport from newer upstream)
  - resolves the DDC bus from `/sys/class/drm/card*-<monitor>/ddc` first, so
    the normal path never runs `ddcutil detect`;
  - uses `--bus`, `--skip-ddc-checks`, `--noverify`, and bounds each DDC call
    with `timeout`;
  - never scans all i2c buses: on AMDGPU a rapid key repeat plus a bus scan
    wedged the display engine (ddcutil issue #223).
- `bin/omarchy-brightness-external` (our script)
  - resolves a connected HDMI/DP output and checks `dpms=On`;
  - takes `flock -n` on `omarchy-brightness-display.lock`, so rapid
    Super+volume events cannot spawn a ddcutil storm;
  - converts `+N`/`-N` to `+N%`/`N%-` and delegates to the DDC helper.
- `bin/omarchy-osd` (our script)
  - turns `-i/-m/-p` into the `osd display` IPC call. Upstream's `osd show`
    method is shadowed by the IpcHandler base and registers no arguments.
- `shell/plugins/osd/Osd.qml`
  - adds `display(payloadJson)` next to `show`; our script uses it.
- `shell/plugins/services/media/Service.qml`
  - drop `playerctld` from `players` (it mirrors the active player and showed
    every source twice).
- `shell/services/AppLibrary.qml`
  - NixOS/niri does not run a UWSM session, so upstream's
    `uwsm-app -- gtk-launch` and `omarchy-launch-tui` are unavailable.
  - GUI and TUI entries launch in a transient
    `systemd-run --user --scope --slice=app.slice` scope, using the parsed
    `Exec` vector / `foot -e`; `gtk-launch` is only the DBus-only fallback.
    This keeps apps out of `omarchy-shell.service`'s cgroup, so a rebuild
    restart cannot kill a Chromium web app or hang on its shutdown.
  - `pkgs/omarchy-shell/default.nix` adds `gtk3`, `gum`, `file` and
    `desktop-file-utils` to the wrapped shell PATH for the web-app helpers.
- `bin/omarchy-webapp-install`, `bin/omarchy-webapp-remove`,
  `bin/omarchy-launch-webapp` (backport from newer upstream)
  - runtime web apps: `.desktop` under `~/.local/share/applications`,
    `StartupWMClass`, and `omarchy-launch-webapp` instead of `uwsm-app`;
  - reads the page title and web app manifest for the name and the largest
    manifest icon, with apple-touch-icon / Google favicon / `/favicon.ico`
    fallbacks;
  - writes `X-Omarchy-WebApp=true` and `X-Omarchy-WebApp-URL=...`, copies the
    icon under `StartupWMClass`, and removes both on uninstall;
  - adding/removing a web app needs no rebuild; Chromium, `gum`, `file` and
    `desktop-file-utils` are runtime dependencies;
  - the old declarative `webapps.nix` / `webapps-tui` / `webapps.json` layer
    was removed, so runtime is the only source of truth.
- `default/omarchy/omarchy-menu.jsonc`
  - Install → Web App and Remove → Web App entries.
- `shell/plugins/bar/indicators/PasswordlessSudo.qml`
  - countdown tooltip from the marker file, live while hovered.
- `shell/plugins/clipboard/` (`Clipboard.qml`, `ClipboardHistory.js`,
  `capture.sh`)
  - port-specific history model: text/image/video entries, first-frame video
    previews, pinned entries, GC and copy-back; `capture.sh` also skips
    `x-kde-passwordManagerHint`, which is what keeps generated passwords out
    of history.
- `shell/Custom/CaptureMenu.qml`, `OpenCodePanel.qml`, `ReminderMenu.qml`,
  `SudoMenu.qml`
  - Escape closes the custom popup.
- `shell/shell.qml`
  - instantiate `NotificationCenter`, `Toasts`, `FileSearch`, `Calc`,
    `DevToolsPanel`, `GalleryPanel`; keep the `ShellIpc` targets used by the
    keybinds.
- `shell/Custom/qmldir`
  - `Toasts`, `DevToolsPanel`, `GalleryPanel` entries.
- `default/omarchy/omarchy-menu.jsonc`
  - minimal NixOS/niri menu with Apps, Files, Calculator, Style
    (Themes/Wallpapers), Capture, System (no Suspend), Hidden apps, Tray icons.
- `bin/omarchy-tray`
  - keep executable; `pkgs/omarchy-shell` symlinks `bin/*` into `$out/bin`.

## Outside the vendor tree

These must be reviewed when an update changes paths or contracts:

- `home-manager/modules/desktop/omarchy/shell.json` — bar layout, disabled
  plugins, intentional tray hidden list, clock in `center` alone.
- `home-manager/modules/desktop/themes.nix` — `theme-set`, `theme-icons`,
  `bg-cycle`, `omarchy-gallery`; theme dirs and wallpaper index.
- `pkgs/omarchy-shell/default.nix` — the launcher wrapper and
  `QT_PLUGIN_PATH` with `qt6.qtimageformats` (WebP previews), `bin/*`
  symlinks, `OMARCHY_SESSION_ID=niri`.
- `home-manager/modules/niri/binds.kdl` — hotkeys for File search, Calculator,
  DevTools, Gallery, Keybindings, notifications, clipboard, System menu.
- `home-manager/modules/niri/keybinds.py` — parser behind `omarchy-keybinds`
  (`home-manager/modules/desktop/default.nix` packages it); rewrite it if the
  binds file format changes.
- `hosts/asus-expertbook/system/services.nix` — WirePlumber rule that renames
  the analog sink to `Laptop Audio`.
- `hosts/asus-expertbook/system/fingerprint.nix` — patched libfprint.
- `docs/omarchy/*` — the port notes; update them with the tag.

## Procedure

1. Fetch the new tag, copy `shell`, `bin`, `config`, `default` and `LICENSE`
   into `vendor/omarchy-shell`; bump `UPSTREAM.md`.
2. Re-apply the patches above (`git log -- vendor/omarchy-shell` is the
   authoritative list of our commits; `git show <commit> -- <file>` gives the
   exact hunks).
3. Keep our files and the `qmldir`/`shell.qml` registrations.
4. Build and preview:

   ```bash
   p=$(nix build --no-link --print-out-paths .#omarchy-shell \
     --option substituters https://cache.nixos.org)
   systemctl --user stop omarchy-shell
   systemd-run --user --unit=omarchy-shell-test --collect \
     "$p/bin/omarchy-launch-shell"
   ```

5. Check the log for `unavailable`, `TypeError`, binding loops; then run the
   bar/panel acceptance in `visual-verification.md` (panels, media, tray,
   gallery, devtools, notifications).
6. Update `themes.nix` if the theme contracts changed (`colors.toml`,
   `palette.json`, wallpapers) and `omarchy-menu.jsonc` if menu providers
   moved.

## What breaks first

The riskiest files are the ones with behaviour, not styling:
`Ui/KeyboardPanel.qml`, `services/media/BarWidget.qml`,
`panels/audio/Panel.qml`, `plugins/bar/widgets/Tray.qml`,
`plugins/menu/Menu.qml`, `shell.qml`. A tag that rewrites any of them needs
its own acceptance pass, not just a build.
