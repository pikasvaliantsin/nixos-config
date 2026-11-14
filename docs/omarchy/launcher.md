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
Mod+D           → Omarchy menu, root
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
Calculator, Capture and System. The upstream Omarchy menu is not copied
wholesale because most of its Arch/Hyprland actions do not exist here.

User entries can override or extend the defaults in:

```text
~/.config/omarchy/extensions/omarchy-menu.jsonc
```

The menu uses the shell's `AppLibrary`, so app rows share icons, launch
feedback and the installed-app list with the rest of the shell.

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
