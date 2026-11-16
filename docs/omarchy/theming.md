# Themes

The theme system supports two sources and generates one directory consumed by
the whole desktop.

## Sources

### Native repository themes

`home-manager/modules/desktop/themes/<name>/` with `palette.json`, for example
`dankViolet`. A native theme may also carry ready-made fragments
(`niri.kdl`, `gtk.css`, `ghostty.conf`, ...); missing files are generated.

`palette.json` keys used by `theme-set`:

- `bg`, `fg`, `fgMuted`;
- `primary` / `secondary` (accent);
- `error`, `warning`, `info`.

### Omarchy themes

A directory under `~/.config/omarchy/themes/<name>/` containing `colors.toml`,
the same format as themes from <https://omarchy.org/themes/>. Install from a
git URL:

```bash
theme-install                                  # asks for the URL
theme-install https://github.com/dhh/omarchy-giants-theme
theme-install https://github.com/<owner>/omarchy-<name>-theme.git
```

`theme-install` clones into `~/.config/omarchy/themes/<name>` (the upstream
`omarchy-<name>-theme` prefix/suffix is stripped for the local name) and then
calls `theme-set <name>`.

Without an argument it asks for the URL with `gum input`, so the Omarchy menu
path **Install → Style → Theme** opens a floating terminal with the same
prompt. The installer mirrors upstream's safety checks: it refuses git options
and transport helpers (`ext::`, `-o…`) and allows only `ssh`, `git`, `http(s)`,
`ftp(s)` and `file`. The clone is `--depth 1` into a hidden temporary directory
next to the themes, the result must contain `colors.toml`, and the existing
theme is replaced only after that check passes. A successful run ends with
`theme-installed <name>`.

The running shell also takes a URL directly: open the theme deck with
`Mod+Alt+T`, press `i`, paste the repository URL, and press Enter. The clone
runs in the background, errors stay in the input card, and the deck reloads
with the new theme selected. Installed themes are runtime state under
`~/.config/omarchy/themes`; they do not need a rebuild or `switch`.

The official Omarchy themes from upstream tag `v4.5.0` are also vendored
under `home-manager/modules/desktop/themes/`: all 23 `colors.toml` palettes,
`icons.theme`, `preview*.png`, `unlock.png`, the small editor/Chromium extras,
and the top-level `backgrounds/*.webp` wallpapers. `theme-set <name>` links
that directory to `current/wallpapers` and applies its first image through
`awww`; `bg-cycle` and the wallpaper deck cycle the rest. Only the large
`backgrounds/intros/` boot videos are omitted to keep the repository smaller.

List installed themes with:

```bash
theme-set
```

Switch:

```bash
theme-set giants
theme-set dankViolet
```

## Generated state

For every switch, `theme-set` builds:

```text
~/.local/state/theme/generated/<name>/
  colors.toml
  shell.toml
  palette.json
  niri.kdl
  gtk.css
  gtklock.css
  btop.theme
  ghostty.conf
  foot.ini
  wallpapers -> <theme source>/{backgrounds,wallpapers}
```

and points these stable links at it:

```text
~/.local/state/theme/current          -> generated/<name>
~/.local/state/omarchy/current/theme  -> generated/<name>
```

`home-manager/modules/desktop/themes.nix` links app configs through
`~/.local/state/theme/current`; the shell reads
`~/.local/state/omarchy/current/theme/`.

Do not hand-edit `generated/`; it is rebuilt on every `theme-set`.

## Dux Files palette bridge

Dux Files is a separate QML application (upstream Quickshell in the current
stable package, embedded `dux-qt-base` in newer releases). It reads the DMS
cache rather than Omarchy's generated theme:

```text
~/.cache/dms/dms-colors.json
~/.cache/dms/dms-typography.json
```

`theme-dms` (from `theme-dms.sh`) derives the Material colour scheme from the
active palette, writes those files atomically, uses Inter/JetBrains Mono, and
sets `org.gnome.desktop.interface color-scheme` from the theme's mode.
`theme-set` calls it after switching `current`, and Home Manager activation
calls it again after login. The old cache was left behind by
DankMaterialShell, which is why a theme switch previously did not reach Dux.
See [`file-manager.md`](file-manager.md).

## Where each fragment goes

- `colors.toml` — foundational palette for the shell `Color` singleton.
- `shell.toml` — bar/surface tokens and typography. If the theme ships its own
  `shell.toml`, it is used instead of the generated minimal one.
- `niri.kdl` — focus ring/border/tab/insert colors. Must be valid KDL: niri
  rejects single-line `{ ... }` blocks without `;` separators.
- `gtk.css` / `gtklock.css` — GTK3/4 and lock screen color overrides.
- `ghostty.conf` / `foot.ini` — terminal palettes. Foot 1.28 uses
  `[colors-dark]`; the generated file also sets `[csd] preferred=none` and does
  not force a global app-id. Normal foot windows therefore tile, and the
  transient helpers pass `org.omarchy.transient` / `org.omarchy.sudo`
  explicitly. The Starship prompt in `home-manager/modules/shell/starship.nix`
  uses ANSI color names (`blue`, `purple`, `yellow`, `bright-black`, `green`),
  so it reads these palettes and follows the theme without a rebuild. Its
  chevron is the Nerd Font `U+E0B1`: the bundled JetBrains Mono has no
  `U+276F`, and foot would fall back to a thin DejaVu Sans glyph.
- `btop.theme` — monitor colors.

## Live application

`theme-set` applies the new theme without a rebuild:

1. writes `colors.toml` and `shell.toml` as base64 and calls the running
   shell's `applyTheme` through `omarchy-ipc` (or `quickshell ipc` fallback);
2. touches the niri theme include so niri reloads border colors;
3. applies the first wallpaper file through `awww`;
4. leaves GTK/GTKLock/btop/terminals to pick up the files on next start
   (the shell updates live).

If `awww-daemon` is not running, `theme-set` and `bg-cycle` start it once.
Use `pgrep -f awww-daemon`; the daemon is a normal `awww-daemon` process.

## Omarchy theme parsing

- `colors.toml` values are quoted hex strings. The parser must not treat the
  `#` inside `"#RRGGBB"` as a comment.
- `bright_*` keys feed terminal palettes; missing ones fall back to the base
  color.
- `mode = "light"` is informational; the UI follows the explicit colors.
- Installed themes are data, not code. Do not execute theme scripts; we only
  consume colors and known fragments.
- `icons.theme` selects the icon theme. It is validated against the user and
  system icon roots; a missing name falls back to Papirus-Dark. The Yaru
  variants (used by some third-party themes) ship with `yaru-theme`, so a theme
  asking for `Yaru-blue-dark` resolves instead of falling back. GTK apps pick
  it up immediately, while Quickshell may need a shell restart.

## Wallpapers

`bg-next` / `bg-prev` cycle wallpapers in the active theme's `wallpapers/`
(or `~/Pictures/Wallpapers` if there is none). The state index is
`~/.local/state/theme/wallpaper.idx`.

## Carousel

`Mod+Alt+T` opens the theme carousel, `Mod+Shift+B` the wallpaper one
(`Mod+Escape` → Style has both). One overlay, two lists, both fed by
`omarchy-gallery`:

- `themes` merges the repository themes and `~/.config/omarchy/themes`,
  preferring the repository copy on a name clash. A card uses `preview.*` when
  the theme ships one, otherwise its first background, and a native theme with
  no artwork gets a palette card from `palette.json`.
- `wallpapers` returns the same sorted list `bg-cycle` uses plus the current
  index, so the carousel and the keyboard cycle never disagree.
- `theme <name>` execs `theme-set`; `wallpaper <index>` writes
  `wallpaper.idx` and runs `awww img` with the usual transition.

The deck is a fan of tall slices: the selected one widens into a preview while
its neighbours stay narrow. `Mod+Alt+T` and `Mod+Shift+B` toggle their deck —
the same hotkey closes it. Arrows/Up/Down and the wheel move, Enter applies.
Applying a theme closes the deck (the pick is the end of the interaction);
wallpapers keep it open so several can be tried in a row.

IPC: `omarchy-ipc call gallery themes|wallpapers|next|previous|apply|close`,
and `gallery status` for the current mode, index, count and name.

### Why not the upstream picker

Omarchy's own carousel is vendored at `shell/plugins/image-picker`, but its
theme mode is driven by two scripts we do not ship: `omarchy-theme-switcher`
(builds a preview cache and `--print-rows`) and `omarchy-menu-images` (summons
the overlay and returns the selection). Both assume upstream state
(`~/.local/state/omarchy/current/theme.name`, `$OMARCHY_PATH/themes`,
`omarchy-theme-set`), while this port owns the pipeline through `theme-set`,
`bg-cycle` and `palette.json`. Wiring them would add ~550 lines of adapter
bash that has to be re-checked on every upstream bump.

The deck above is the smaller renderer over `omarchy-gallery`. If a future
Omarchy release brings something we actually need from the picker (video
previews, theme deletion, filtering), swap only the renderer: summon
`omarchy.image-picker` with rows derived from `omarchy-gallery themes`, and
feed the selection file back into `theme-set` / `omarchy-gallery wallpaper`.


## Verification

After a switch, check the bar, panels, active/inactive borders, a new terminal
and a new GTK window. For a theme installed from git, confirm
`readlink -f ~/.local/state/theme/current` points at
`generated/<name>`, and that `shell.toml` contains the expected `bg`/`fg`/
`accent` rather than fallbacks (`#101315`, `#cacccc`).

A generated `niri.kdl` can be checked with:

```bash
niri validate -c ~/.local/state/theme/current/niri.kdl
```
