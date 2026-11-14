# Keybindings

`Mod+Shift+Slash` opens a searchable sheet of every bind in the niri config;
the same entry is in `Mod+Escape` → Keybindings.

- `shell/Custom/KeybindsPanel.qml` is the overlay: a filter field, one row per
  bind (keys, title), grouped by the `// --- … ---` sections in `binds.kdl`.
  `Esc` and a click outside close it.
- `home-manager/modules/niri/keybinds.py`, packaged as `omarchy-keybinds`,
  parses the live `~/.config/niri/binds.kdl` and prints
  `{sections: [{title, items: [{keys, title, action}]}]}`. It reads the file on
  every open, so the sheet follows the compositor without a rebuild.
- Titles come from `hotkey-overlay-title`; binds without one show their action.
  The action stays searchable even though the row shows only the title.

IPC: `omarchy-ipc call keybinds open|close|toggle|reload`, and
`keybinds status` for the section/binding counts and the current query.

The sheet is ours, not upstream's `omarchy-menu-keybindings`: that script uses
`hyprctl binds`, which niri does not have.
