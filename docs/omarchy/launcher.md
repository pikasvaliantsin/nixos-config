# Launcher, file search and calculator

Walker and Elephant are intentionally no longer used. The desktop has one
Quickshell stack:

- application menu and app search: `omarchy.menu`;
- file search: `dsearch` through `Custom/FileSearch.qml`;
- calculator: `qalc` through `Custom/Calc.qml`;
- window review: niri `Mod+Tab` overview;
- web search: browser/AI, not a launcher mode.

## Bindings

```kdl
Alt+Space       → Omarchy menu, Apps submenu
Mod+D           → Omarchy menu, Apps submenu
Mod+Escape      → Omarchy menu, root
Mod+Shift+D     → dsearch file search
Mod+Shift+C     → qalc calculator
```

The bindings live in `home-manager/modules/niri/binds.kdl` and call
`omarchy-ipc`; they do not start a second Quickshell instance.

## Omarchy menu

The menu plugin ships with the shell and is active because it is not listed in
`disabledPlugins` in `shell.json`. The local defaults are in:

```text
vendor/omarchy-shell/default/omarchy/omarchy-menu.jsonc
```

This is deliberately a minimal menu for the NixOS/niri port: Apps, Files,
Calculator, Capture, Install/Remove (web apps) and System. The upstream
Omarchy menu is not copied wholesale because most of its Arch/Hyprland actions
do not exist here.

User entries can override or extend the defaults in:

```text
~/.config/omarchy/extensions/omarchy-menu.jsonc
```

The menu uses the shell's `AppLibrary`, so app rows share icons, launch
feedback and the installed-app list with the rest of the shell.

Opening a submenu records the current cursor row. Going back with
`Escape`/Left/Backspace returns to that row instead of resetting the
selection to the first entry.

### Pinning and hiding apps

The Apps submenu keeps its own state under `~/.config/omarchy/`:

- `launcher.pins` — pinned desktop IDs, one per line; line order is display
  order;
- `launcher.hides` — hidden desktop IDs, one per line.

Pinned apps sit above the alphabetical list and carry a pin glyph.

| Keys | Action |
|---|---|
| `Ctrl+P` | pin/unpin the selected app |
| `Ctrl+Up` / `Ctrl+Down` | move a pinned app up/down (empty filter only) |
| `Ctrl+H` | hide the selected app |

Hiding a pinned app also removes its pin. Hidden apps disappear from Apps and
from search. Restore them through `Mod+Escape` → System → **Hidden apps**;
Enter puts the app back. Only apps hidden by the user appear there —
`NoDisplay`/`Hidden` entries and the shipped `launcher.hides` are not
restorable this way.

Files are rewritten atomically and watched, so edits from an editor apply
without restarting the shell. Pins for uninstalled apps are ignored.

## Web apps

Runtime web apps follow the upstream Omarchy model: a `.desktop` file that
runs a Chromium-based browser with `--app=<url>`.

```bash
omarchy-webapp-install "Twitch" "https://twitch.tv" "twitch"
omarchy-webapp-remove "Twitch"
```

- Install and Remove are in the Omarchy menu (`Install → Web App`,
  `Remove → Web App`); they open in a floating `foot` terminal and do not
  require a rebuild.
- The installer writes `~/.local/share/applications/<name>.desktop`, downloads
  the site icon, and sets `StartupWMClass` so the dock/taskbar associates the
  window with the web app.
- `omarchy-launch-webapp` selects a Chromium-based browser. Set
  `OMARCHY_WEBAPP_BROWSER` to an absolute browser path to force a different
  Chromium-based browser.
- The installer asks for the URL first, then looks up the name and the best
  icon automatically (web app manifest → apple-touch-icon → Google favicon →
  `/favicon.ico`); the icon URL is only requested if every source fails.
- There is no separate declarative TUI anymore: every web app is a runtime
  `.desktop` file under `~/.local/share/applications` and is managed by
  Install/Remove.

Apps launched from the menu (including web apps) run in a transient
`systemd-run --user --scope --slice=app.slice` scope. They therefore do not
inherit `omarchy-shell.service`'s cgroup and survive shell restarts and
rebuilds; this is the NixOS/niri replacement for upstream's `uwsm-app`.

### Chromium/Electron and the keyring

Chromium and Electron use `--password-store=basic`:

- `omarchy-launch-webapp` adds the flag to every web app;
- `~/.local/bin/chromium`, `obsidian` and `vesktop` are wrappers that add it
  to the corresponding binaries.

This avoids the "Unlock Login Keyring" dialog. The login keyring is not
unlocked after a fingerprint login: `pam_fprintd` is `sufficient` in the PAM
stack and skips `pam_gnome_keyring`. With the basic store, Chromium/Electron
keep their secrets in their own profile instead of libsecret.

If the login keyring is later unlocked at login (for example by using a
password login and a keyring password that matches it), remove the wrappers
and the flag from `omarchy-launch-webapp` to get OS-keyring protection back.

## dsearch

`programs.dsearch` is enabled in
`home-manager/modules/desktop/default.nix`. The service indexes
`$HOME` at depth 6, excludes `result` and common build/cache directories, and
stores its index under `~/.cache/dsearch/index`.

The CLI is the integration surface:

```bash
dsearch search --json --limit 50 --type file --fuzzy "query"
```

`Custom/FileSearch.qml` opens as one full-screen `OverlayWindow`, debounces
input, and parses `.hits[].id` from that JSON.

Rows support:

- Enter — open the file with `xdg-open`;
- Ctrl+Enter — open the containing directory;
- Ctrl+C — copy the path with `wl-copy`;
- Escape or a click outside — close.

After changing the index configuration, restart the service and rebuild the
index:

```bash
systemctl --user restart dsearch
dsearch index generate
dsearch index status
```

`dsearch index sync` is enough for ordinary incremental changes. A full
`generate` is needed after exclusions change, because old entries are not
removed by a sync.

## Calculator

`Custom/Calc.qml` runs:

```bash
qalc -t "<expression>"
```

Enter copies the current result to the clipboard; Escape or an outside click
closes it. `libqalculate` provides the `qalc` binary.

## Testing

```bash
omarchy-ipc call shell toggle omarchy.menu '{"menu":"root"}'
omarchy-ipc call shell toggle omarchy.menu '{"menu":"apps"}'
omarchy-ipc call local.file-search toggle
omarchy-ipc call local.calc toggle
```

Do UI checks only when the desktop is on a safe workspace. Check that Walker
and Elephant are gone:

```bash
systemctl --user is-active walker elephant   # inactive
pgrep -af 'walker|elephant'
```
