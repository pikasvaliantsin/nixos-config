# Testing and acceptance

There is no copy of the upstream Omarchy test suite in `vendor/omarchy-shell`.
Use the Nix build plus a running preview shell for QML and visual checks.

## Static checks

```bash
cd ~/nixos-config
git diff --check
find vendor/omarchy-shell/default/i18n -name '*.json' -exec jq empty {} +
niri validate -c home-manager/modules/niri/config.kdl
niri validate -c ~/.local/state/theme/current/niri.kdl
```

`niri validate` on a theme only works after `theme-set` has generated the
file.

## Build

Always pass the substituter; the local cache endpoint may be unreachable.

```bash
nixos-rebuild build --flake .#asus-expertbook \
  --option substituters https://cache.nixos.org
```

This checks Nix evaluation and packages. It does **not** load QML. For QML, build
the shell package and start a preview:

```bash
p=$(nix build --no-link --print-out-paths .#omarchy-shell \
  --option substituters https://cache.nixos.org)
```

Follow [`visual-verification.md`](visual-verification.md) for the stop/preview/
restore sequence. Read the shell log for QML errors:

```bash
journalctl --user -u omarchy-shell-test --no-pager | tail -50
ls -t "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/quickshell/by-id/*/log.qslog | head -1
```

Use `strings` on the `.qslog` if needed; it contains binary separators.

## Applying

```bash
nixos-rebuild switch --flake .#asus-expertbook \
  --option substituters https://cache.nixos.org
systemctl --user restart omarchy-shell
```

Only switch with explicit sudo. Do not assume the user's temporary
passwordless sudo is available.

## Clipboard GC

The GC helper has test overrides:

```bash
gc=$(for d in $(ls -dt /nix/store/*-clipboard-gc); do
  [ -x "$d/bin/clipboard-gc" ] && grep -q CLIPBOARD_GC_MAX_BYTES "$d/bin/clipboard-gc" && echo "$d" && break
done)

t=/tmp/opencode/gc-test
rm -rf "$t" && mkdir -p "$t/images"
truncate -s 1M "$t/images/a.png" "$t/images/b.png" "$t/images/c.png" "$t/images/orphan.png"
cat >"$t/history.json" <<EOF
[{"type":"image","path":"$t/images/a.png","pinned":true},
 {"type":"image","path":"$t/images/b.png"},
 {"type":"image","path":"$t/images/c.png"}]
EOF

CLIPBOARD_GC_STATE_DIR="$t" CLIPBOARD_GC_MAX_BYTES=1572864 \
  "$gc/bin/clipboard-gc"
```

Expect: orphan removed, oldest unpinned files removed until under the limit,
pinned file kept. With invalid JSON the script must exit non-zero and remove
nothing.

The live GC is safe to run manually:

```bash
clipboard-gc
```

It removes files not referenced by `history.json`; it never touches pinned
entries directly.

## Theme tests

```bash
theme-set giants              # if installed
readlink -f ~/.local/state/theme/current
head -20 ~/.local/state/theme/current/shell.toml
niri validate -c ~/.local/state/theme/current/niri.kdl
theme-set dankViolet   # return to a known native theme
```

Expected Omarchy theme values are the explicit `colors.toml` values; fallback
`#101315`/`#cacccc` means parsing failed. Verify a newly started terminal and
GTK app only after the theme files are written.

## Notifications

```bash
omarchy-notification-send "Test summary" "Test body"
omarchy-ipc call notifications open
omarchy-ipc call notifications clear   # active -> history
```

Check active cards, history (use the History "Clear" link to empty it), action
labels, Escape, and click outside. DND records new notifications in history
instead of showing live cards; turn it off to test the normal path. History and
DND are persisted, so a shell restart should keep both.

## Destructive-test safety

- Back up `~/.local/state/quickshell/clipboard/history.json` before clearing
  the user's clipboard history; clearing does not remove image files until GC.
- `~/.local/state/omarchy/notifications/history.json` is real notification
  history, not a cache; `notifications clear` and the History "Clear" link
  mutate it.
- Do not run `clipboard-gc` with a custom state path that points at the live
  directory unless you intend to prune it.
- Do not kill all `quickshell` processes; the calendar shell is separate.
- Restore `omarchy-shell.service` after every preview and leave no
  `omarchy-shell-test` unit running.

## Final checklist

- [ ] `git diff --check` clean.
- [ ] `nixos-rebuild build` passes.
- [ ] QML preview loads without new errors in the log.
- [ ] visual change inspected on the focused output.
- [ ] service restarted / generation applied.
- [ ] unrelated user changes remain unstaged/uncommitted.
