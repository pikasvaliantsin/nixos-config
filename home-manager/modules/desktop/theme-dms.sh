# shellcheck shell=bash
# Publish the active Omarchy theme in the DMS cache format that Dux Files
# reads. Dux stayed on a stale DankMaterialShell palette because nothing
# updates ~/.cache/dms after the switch to the Omarchy shell. This script is
# called by theme-set and after every Home Manager activation.

set -euo pipefail

state="${XDG_STATE_HOME:-$HOME/.local/state}/theme/current"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/dms"

theme_dir=$(readlink -f "$state" 2>/dev/null || printf '%s' "$state")
theme_name=$(basename "$theme_dir" 2>/dev/null || printf '')
palette="$state/palette.json"
colors="$state/colors.toml"

fallback_bg="#101315"
fallback_fg="#cacccc"
fallback_accent="#cacccc"
fallback_muted="#707880"
fallback_outline="#414868"
fallback_error="#a55555"

toml_get() {
  local key="$1" file="$2"
  [ -f "$file" ] || return 0
  awk -v key="$key" '
    {
      line = $0
      sub(/^[[:space:]]*/, "", line)
      if (line !~ "^" key "[[:space:]]*=") next
      sub(/^[^=]*=[[:space:]]*/, "", line)
      if (line ~ /^"/) {
        sub(/^"/, "", line)
        sub(/".*$/, "", line)
      } else {
        sub(/[[:space:]]*#.*$/, "", line)
        sub(/[[:space:]]+$/, "", line)
      }
      print line
      exit
    }
  ' "$file"
}

# mix_hex "#rrggbb" "#rrggbb" ratio -> ratio of the first colour
mix_hex() {
  local first="${1#\#}" second="${2#\#}" ratio="$3"
  awk -v a="$first" -v b="$second" -v p="$ratio" 'BEGIN {
    ar = strtonum("0x" substr(a, 1, 2))
    ag = strtonum("0x" substr(a, 3, 2))
    ab = strtonum("0x" substr(a, 5, 2))
    br = strtonum("0x" substr(b, 1, 2))
    bg = strtonum("0x" substr(b, 3, 2))
    bb = strtonum("0x" substr(b, 5, 2))
    r = int(ar * p + br * (1 - p) + 0.5)
    g = int(ag * p + bg * (1 - p) + 0.5)
    bl = int(ab * p + bb * (1 - p) + 0.5)
    printf "#%02x%02x%02x\n", r, g, bl
  }'
}

mode="dark"
if [ -f "$palette" ]; then
  mode=$(jq -r '.mode // empty' "$palette")
  bg=$(jq -r '.bg // .surface // empty' "$palette")
  surface=$(jq -r '.surface // .bg // empty' "$palette")
  surface_container=$(jq -r '.surfaceContainer // .surface // empty' "$palette")
  surface_container_high=$(jq -r '.surfaceContainerHigh // .surfaceContainer // .surface // empty' "$palette")
  fg=$(jq -r '.fg // empty' "$palette")
  muted=$(jq -r '.fgMuted // .outline // empty' "$palette")
  primary=$(jq -r '.primary // .secondary // empty' "$palette")
  primary_text=$(jq -r '.primaryText // .bg // empty' "$palette")
  secondary=$(jq -r '.secondary // .primary // empty' "$palette")
  outline=$(jq -r '.outline // .fgMuted // empty' "$palette")
  error=$(jq -r '.error // .primary // empty' "$palette")
  warning=$(jq -r '.warning // .error // empty' "$palette")
  info=$(jq -r '.info // .primary // empty' "$palette")
  tertiary="$secondary"
  green="$primary"
  yellow="$warning"
  blue="$info"
  cyan="$info"
  magenta="$secondary"
  bright_red="$error"
  bright_green="$green"
  bright_yellow="$yellow"
  bright_blue="$blue"
  bright_magenta="$magenta"
  bright_cyan="$cyan"
else
  mode=$(toml_get mode "$colors")
  bg=$(toml_get background "$colors")
  fg=$(toml_get foreground "$colors")
  primary=$(toml_get accent "$colors")
  primary_text="$bg"
  muted=$(toml_get muted "$colors")
  outline=$(toml_get selection "$colors")
  [ -n "$outline" ] || outline="$muted"
  error=$(toml_get red "$colors")
  warning=$(toml_get orange "$colors")
  green=$(toml_get green "$colors")
  yellow=$(toml_get yellow "$colors")
  blue=$(toml_get blue "$colors")
  cyan=$(toml_get cyan "$colors")
  magenta=$(toml_get magenta "$colors")
  tertiary="$magenta"
  secondary="$primary"
  surface=$(toml_get background "$colors")
  surface_container="$surface"
  surface_container_high=$(toml_get lighter_background "$colors")
  [ -n "$surface_container_high" ] || surface_container_high="$surface"
  bright_red=$(toml_get bright_red "$colors")
  bright_green=$(toml_get bright_green "$colors")
  bright_yellow=$(toml_get bright_yellow "$colors")
  bright_blue=$(toml_get bright_blue "$colors")
  bright_magenta=$(toml_get bright_magenta "$colors")
  bright_cyan=$(toml_get bright_cyan "$colors")
fi

case "$theme_name" in
  *latte*|*light*|*dawn*|*day*) [ -z "$mode" ] && mode="light" ;;
esac
[ -n "$mode" ] || mode="dark"

bg=${bg:-$fallback_bg}
fg=${fg:-$fallback_fg}
primary=${primary:-$fallback_accent}
primary_text=${primary_text:-$bg}
secondary=${secondary:-$primary}
tertiary=${tertiary:-$secondary}
surface=${surface:-$bg}
surface_container=${surface_container:-$surface}
surface_container_high=${surface_container_high:-$surface_container}
muted=${muted:-$fallback_muted}
outline=${outline:-$fallback_outline}
error=${error:-$fallback_error}
warning=${warning:-$error}
info=${info:-$primary}

bright_red=${bright_red:-$error}
bright_green=${bright_green:-$green}
bright_yellow=${bright_yellow:-$yellow}
bright_blue=${bright_blue:-$blue}
bright_magenta=${bright_magenta:-$magenta}
bright_cyan=${bright_cyan:-$cyan}

surface_container_lowest=$(mix_hex "$surface" "#000000" 0.88)
surface_container_low=$(mix_hex "$surface" "$fg" 0.97)
surface_container_highest=$(mix_hex "$surface_container_high" "$fg" 0.90)
surface_variant="$surface_container_high"
surface_bright=$(mix_hex "$surface" "$fg" 0.88)
surface_dim=$(mix_hex "$surface" "#000000" 0.82)
outline_variant=$(mix_hex "$bg" "$fg" 0.82)
on_surface_variant=$(mix_hex "$fg" "$bg" 0.78)
primary_container=$(mix_hex "$bg" "$primary" 0.78)
secondary_container=$(mix_hex "$bg" "$secondary" 0.82)
tertiary_container=$(mix_hex "$bg" "$tertiary" 0.82)
error_container=$(mix_hex "$bg" "$error" 0.78)
inverse_surface="$fg"
inverse_on_surface="$bg"

mkdir -p "$cache"
chmod 700 "$cache" 2>/dev/null || true

tmp=$(mktemp "$cache/.dms-colors.XXXXXX")
jq -n \
  --arg mode "$mode" \
  --arg primary "$primary" \
  --arg primary_text "$primary_text" \
  --arg primary_container "$primary_container" \
  --arg on_primary_container "$fg" \
  --arg secondary "$secondary" \
  --arg secondary_container "$secondary_container" \
  --arg on_secondary_container "$fg" \
  --arg tertiary "$tertiary" \
  --arg tertiary_container "$tertiary_container" \
  --arg on_tertiary_container "$fg" \
  --arg surface "$surface" \
  --arg on_surface "$fg" \
  --arg surface_variant "$surface_variant" \
  --arg on_surface_variant "$on_surface_variant" \
  --arg surface_tint "$primary" \
  --arg surface_bright "$surface_bright" \
  --arg surface_dim "$surface_dim" \
  --arg background "$bg" \
  --arg on_background "$fg" \
  --arg outline "$outline" \
  --arg outline_variant "$outline_variant" \
  --arg surface_container_lowest "$surface_container_lowest" \
  --arg surface_container_low "$surface_container_low" \
  --arg surface_container "$surface_container" \
  --arg surface_container_high "$surface_container_high" \
  --arg surface_container_highest "$surface_container_highest" \
  --arg inverse_surface "$inverse_surface" \
  --arg inverse_on_surface "$inverse_on_surface" \
  --arg scrim "#000000" \
  --arg error "$error" \
  --arg on_error "$primary_text" \
  --arg error_container "$error_container" \
  --arg on_error_container "$fg" \
  'def scheme: {
      primary: $primary,
      on_primary: $primary_text,
      primary_container: $primary_container,
      on_primary_container: $on_primary_container,
      secondary: $secondary,
      secondary_container: $secondary_container,
      on_secondary_container: $on_secondary_container,
      tertiary: $tertiary,
      tertiary_container: $tertiary_container,
      on_tertiary_container: $on_tertiary_container,
      surface: $surface,
      on_surface: $on_surface,
      surface_variant: $surface_variant,
      on_surface_variant: $on_surface_variant,
      surface_tint: $surface_tint,
      surface_bright: $surface_bright,
      surface_dim: $surface_dim,
      background: $background,
      on_background: $on_background,
      outline: $outline,
      outline_variant: $outline_variant,
      surface_container_lowest: $surface_container_lowest,
      surface_container_low: $surface_container_low,
      surface_container: $surface_container,
      surface_container_high: $surface_container_high,
      surface_container_highest: $surface_container_highest,
      inverse_surface: $inverse_surface,
      inverse_on_surface: $inverse_on_surface,
      scrim: $scrim,
      error: $error,
      on_error: $on_error,
      error_container: $error_container,
      on_error_container: $on_error_container
    };
    {mode: $mode, colors: {dark: scheme, light: scheme}}' >"$tmp"
chmod 600 "$tmp"
mv "$tmp" "$cache/dms-colors.json"

tmp=$(mktemp "$cache/.dms-typography.XXXXXX")
printf '%s\n' \
  '{"fontFamily":"Inter","monoFontFamily":"JetBrains Mono","displayFontFamily":"Inter","fontWeight":400,"fontScale":1}' \
  >"$tmp"
chmod 600 "$tmp"
mv "$tmp" "$cache/dms-typography.json"

# Dux follows the portal colour scheme; libadwaita/GTK apps should follow the
# same value instead of staying permanently dark after a light theme switch.
if command -v gsettings >/dev/null 2>&1; then
  if [ "$mode" = "light" ]; then
    gsettings set org.gnome.desktop.interface color-scheme "default" >/dev/null 2>&1 || true
  else
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" >/dev/null 2>&1 || true
  fi
fi
