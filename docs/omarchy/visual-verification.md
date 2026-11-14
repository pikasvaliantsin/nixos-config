# Visual verification

Read this before finishing a change with a visual effect: shell layout, bar,
panels, overlays, notifications, clipboard, themes, screenshots, recording or
animations.

A build is not verification. Inspect the running UI for clipping, overlap,
wrong spacing, stale state, focus problems, and one-click/two-click surprises.
For this repository, verify on the actual niri session (or a preview shell on
it) and restore the user's shell afterwards.

## Screenshots

`grim` is the reliable tool in this session:

```bash
grim -o HDMI-A-1 /tmp/opencode/full.png          # whole output
grim -g "0,0 400x120" /tmp/opencode/crop.png     # exact region
```

Use the output names from `niri msg outputs`. For two monitors, capture both
when the change affects the bar or a layer surface on each. For small controls
(pills, icons, spacing), capture a crop; do not judge a 380px card from a
downscaled full-screen image.

The packaged capture helpers are also available:

```bash
omarchy-capture-screenshot region
omarchy-capture-screenshot screen
omarchy-capture-screenshot window
```

They save under `~/Pictures/Screenshots` and copy the result. On a 75% keyboard
without `Print`, use `Super+Shift+S` (region), `Mod+Ctrl+S` (screen) and
`Mod+Ctrl+Shift+S` (window).

## Recording

Use the repo's recorder (wl-screenrec, wf-recorder fallback):

```bash
omarchy-capture-screenrecording --fullscreen --with-desktop-audio
# exercise the behaviour
omarchy-capture-screenrecording --stop-recording
```

Audio modes: no audio, desktop audio (`pactl get-default-sink` monitor), and
desktop + the system default microphone (`pactl get-default-source`). Flags are
`--with-desktop-audio` and `--with-microphone-audio`; both use a temporary
`omarchy_screenrec` null sink and loopbacks that must be gone after stop:

```bash
pactl list short modules | grep omarchy_screenrec   # empty when idle
```

Bindings are `Alt+R` (screen) and `Alt+Shift+R` (region), both with desktop
audio by default. The bar recording indicator is also a button: while
recording it stops, otherwise it opens the capture menu with the audio mode.
The mode is stored in `~/.local/state/omarchy/screenrecord-audio`.

Recording files land in `~/Videos/Screencasts/` (override with
`OMARCHY_SCREENRECORD_DIR`) for both backends. After stop every recording is
copied to the clipboard as a `file://` URI; the clipboard watcher adds a
`video` history entry with a first-frame thumbnail (copying that entry puts the
video file back on the clipboard). Check the audio track and the clipboard:

```bash
nix shell nixpkgs#ffmpeg -c ffprobe -v error \
  -show_entries stream=codec_type,codec_name -of compact=p=0 "$file"
wl-paste --type text/uri-list
```

Keep recordings short and focused.

To inspect frames, use ffmpeg from nixpkgs (ffmpeg is not installed globally):

```bash
nix shell nixpkgs#ffmpeg -c bash -c '
  for t in 0 2 4 6 8; do
    ffmpeg -loglevel error -ss "$t" -i "$1" -frames:v 1 -y "/tmp/opencode/f-$t.png"
  done
' _ /path/to/record.mp4
```

Read the frames rather than relying on the motion at full speed.

## Preview shell

The shell QML lives in the Nix store; a source edit needs a new package before
the running shell can use it.

```bash
cd ~/nixos-config
nix build --no-link --print-out-paths .#omarchy-shell --option substituters https://cache.nixos.org
```

Then, with the store path in `$p`:

```bash
# Stop the deployed service; do not leave two shells running.
systemctl --user stop omarchy-shell
pgrep -af 'quickshell -p .*omarchy-shell'   # should show nothing

systemctl --user reset-failed omarchy-shell-test 2>/dev/null || true
systemd-run --user --unit=omarchy-shell-test --collect "$p/bin/omarchy-launch-shell"

# ... exercise the UI ...

systemctl --user stop omarchy-shell-test
systemctl --user start omarchy-shell
```

The preview inherits the session PATH. If a helper is only in the new
home-manager generation and not in the session, pass it explicitly:

```bash
systemd-run --user --unit=omarchy-shell-test --collect \
  --setenv=PATH="/nix/store/...-clipboard-copy/bin:/nix/store/...-image-size/bin:$PATH" \
  "$p/bin/omarchy-launch-shell"
```

Never kill all `quickshell` processes blindly; the calendar shell and other
components may be separate. Check the process list first.

## Driving the UI

- IPC is the same path as a click on a panel icon:
  `omarchy-ipc call shell toggle omarchy.clipboard`,
  `omarchy-ipc call notifications open`, etc.
- `omarchy-ipc` finds the preview shell too; verify with
  `omarchy-ipc call shell ping`.
- Keys: `nix shell nixpkgs#wtype -c wtype -k Escape` or `-k Right -k Return`.
- Pointer and wheel: `nix shell nixpkgs#wlrctl -c wlrctl pointer move 120 0`
  or `... pointer scroll 120 0`. A large negative move clamps to the top-left,
  which gives a known origin for absolute positioning.
- Niri state: `niri msg --json workspaces`, `niri msg --json windows`,
  `niri msg layers`, `niri msg focused-window`.
- Notifications: `omarchy-notification-send` (or `notify-send` for a quick
  test). Remember that DND records new notifications in history without a
  live card, and that history and DND survive a shell restart.

## Bar controls

- Volume wheel: scroll over the speaker icon. The output volume changes in 5%
  steps, the workspace must not change, and the Omarchy OSD appears at the
  bottom with the volume percentage and progress bar.
- The OSD is the upstream `omarchy.osd` panel, enabled in `shell.json`; the
  audio bar widget consumes the wheel so the bar's workspace scroller does not
  also fire.
- Launcher: `Mod+D` and `Alt+Space` open the Apps search, `Mod+Escape` opens
  the root menu, `Mod+Shift+D` opens the dsearch file finder and `Mod+Shift+C`
  opens the calculator. In the menu, walk the cursor into a submenu and go
  back: the row must stay selected. Check Walker/Elephant are inactive.
- Apps state: pin two apps with `Ctrl+P`, reorder them with `Ctrl+Up/Down`,
  restart the shell and confirm the order survives. Hide one with `Ctrl+H`,
  then restore it from `System → Hidden apps`. A hidden pinned app must lose
  its pin.
- Calculator: the card shows `0` and keeps the same height from opening until
  a result arrives.
- Developer tools: `Mod+Shift+X` opens the toolbox. Switch tools with the rail
  and the search field, generate a UUID v4 and v7 (check the version nibble),
  format JSON with sorting, decode a JWT, convert a timestamp and a colour,
  run a regex, diff two texts and check chmod 4755. Escape and a click outside
  close it. Paste >32 KiB into Base64 and confirm the footer says it is using
  `base64`, and that the output still decodes back.
- Port forwarding: the right-side widget reads
  `~/.config/omarchy/port-forwards.json`. Add a forward, turn it on, confirm the
  `omarchy-pf-<id>.service` transient unit and the listening local port, then
  restart the shell and confirm the tunnel/status is reconciled. Auth must be
  SSH key/agent only; host-key and Tailscale approval errors appear in the
  status. `omarchy-ipc call port-forward list` is the headless check.
- Tray: left click an icon opens its menu inside a KeyboardPanel; the footer
  has Pin/Unpin and Hide. Pin keeps the menu open and moves the icon into the
  bar; Hide closes the menu and removes the icon. Escape and a click outside
  close the menu. Restore hidden icons through `Mod+Escape` → System → Tray.
- System: `Super+X` opens the Omarchy System submenu (not wlogout). It has
  Lock, Logout, Reboot, Shutdown, Hidden apps and Tray icons; it must not offer
  Suspend.
- Power panel: open `omarchy.power` and check the battery size, real health,
  charge limit, time left/to full, state and power draw. Cycle count is not
  shown: this battery reports `0` in sysfs and `N/A` in UPower, so there is no
  real value to display.
- Keyboard layout: the widget sits right of the clock. With Caps Lock off the
  layout code is lowercase (`ru`), with it on uppercase (`RU`); a click cycles
  the layout. Layout switches and Caps Lock changes both show the bottom OSD.
  Caps Lock is a lock again, not Ctrl: `ctrl:nocaps` was removed from the niri
  xkb options. Do not add it back if the bar indicator is expected to work.

## Themes and wallpapers

After `theme-set`/`theme-install`, verify:

- bar and popup colors;
- active/inactive borders;
- GTK CSS for a newly opened GTK app;
- Ghostty/foot colors for a newly opened terminal;
- btop if the theme provides it;
- icon theme: add `icons.theme` with an installed set, run `theme-set`, and
  check `gsettings get org.gnome.desktop.interface icon-theme` plus a new GTK
  app. A missing or invalid set must fall back to Papirus-Dark;
- wallpaper on both outputs.

`theme-set` applies colors to the live shell through the shell's `applyTheme`
IPC. If the shell is a preview instance, `omarchy-ipc` should find it.

## Clipboard and notification panels

- Clipboard: open with `omarchy-ipc call shell toggle omarchy.clipboard`.
  Check tabs, search, pin icon, hover on the miniature, copy, delete, clear.
- Notification center: `omarchy-ipc call notifications open`.
  Check active cards, history after `clear`/dismiss, Escape, click outside,
  actions and DND.

The clipboard and the notification center are each one full-screen overlay
with their own scrim, so both close on the first outside click. If either
takes two clicks, the scrim, card and key catcher have drifted into separate
surfaces again; see [`notifications.md`](notifications.md).

## Finish

Before calling the change done:

- inspect the screenshots/recording, not just the build output;
- restore `omarchy-shell.service` and confirm it is active;
- leave no `omarchy-shell-test` unit or old preview shell running;
- remove temporary screenshots/videos from the repo (use `/tmp/opencode/`).
