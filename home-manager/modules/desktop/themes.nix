# Система тем: один каталог темы — фрагменты для всего стека.
#
# Два источника:
#   * native — каталог в репозитории (home-manager/modules/desktop/themes)
#     с palette.json и, опционально, готовыми фрагментами;
#   * Omarchy — каталог в ~/.config/omarchy/themes с colors.toml, как у тем
#     с omarchy.org (ставится через `theme-install <git-url>`).
#
# theme-set собирает из любого источника ~/.local/state/theme/generated/<name>
# (colors.toml, shell.toml, niri.kdl, gtk.css, ghostty.conf, foot.ini,
# btop.theme), переключает симлинки и отдаёт новые цвета живой
# оболочке через IPC applyTheme. Пересборка не нужна; btop/gtklock/GTK
# подхватят при следующем запуске.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) mkOption types;
  inherit (config.mySystem) dotfilesRoot;

  themesDir = "${dotfilesRoot}/home-manager/modules/desktop/themes";
  stateDir = "${config.home.homeDirectory}/.local/state/theme";
  current = "${stateDir}/current";
  # Niri резолвит include относительно каталога конфига. Конфиг — симлинк
  # в репозиторий, поэтому theme.kdl нужен в обоих местах.
  repoThemeLink = "${dotfilesRoot}/home-manager/modules/niri/theme.kdl";

  # Список тем берём из flake-дерева (доступно в pure eval), а пути для
  # рантайма остаются строками в репозитории, чтобы theme-set мог
  # переключать симлинк без пересборки.
  available = builtins.attrNames (builtins.readDir ./themes);

  cfg = config.mySystem.theme;

  mkLink = path: config.lib.file.mkOutOfStoreSymlink path;

  themeIcons = pkgs.writeShellApplication {
    name = "theme-icons";
    runtimeInputs = [ pkgs.coreutils pkgs.glib pkgs.gnugrep pkgs.gnused ];
    text = ''
      set -euo pipefail
      fallback="Papirus-Dark"
      roots=()
      add_root() { [ -d "$1" ] && roots+=("$1") || true; }

      add_root "$HOME/.icons"
      add_root "$HOME/.local/share/icons"
      add_root "''${XDG_DATA_HOME:-$HOME/.local/share}/icons"
      add_root "$HOME/.nix-profile/share/icons"
      add_root "/etc/profiles/per-user/''${USER}/share/icons"
      add_root "/run/current-system/sw/share/icons"
      IFS=: read -r -a data_dirs <<< "''${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
      for data_dir in "''${data_dirs[@]}"; do add_root "$data_dir/icons"; done

      resolve() {
        local wanted="''${1:-}" root
        [ -n "$wanted" ] || return 1
        for root in "''${roots[@]}"; do
          if [ -d "$root/$wanted" ]; then
            printf '%s\n' "$wanted"
            return 0
          fi
        done
        return 1
      }

      apply_gtk() {
        local name=$1 version file tmp
        for version in 3.0 4.0; do
          file="$HOME/.config/gtk-$version/settings.ini"
          mkdir -p "$(dirname "$file")"
          tmp=$(mktemp)
          if [ -e "$file" ]; then cat "$file" >"$tmp"; fi
          if grep -q '^gtk-icon-theme-name=' "$tmp" 2>/dev/null; then
            sed -i "s|^gtk-icon-theme-name=.*|gtk-icon-theme-name=$name|" "$tmp"
          elif grep -q '^\[Settings\]' "$tmp" 2>/dev/null; then
            sed -i "/^\[Settings\]/a gtk-icon-theme-name=$name" "$tmp"
          else
            if [ -s "$tmp" ]; then printf '\n' >>"$tmp"; fi
            printf '[Settings]\ngtk-icon-theme-name=%s\n' "$name" >>"$tmp"
          fi
          chmod 644 "$tmp"
          # HM links this file into the store; replace the link with a
          # writable settings file so a runtime icon choice can stick.
          rm -f "$file"
          mv "$tmp" "$file"
        done
        if command -v gsettings >/dev/null 2>&1; then
          gsettings set org.gnome.desktop.interface icon-theme "$name" >/dev/null 2>&1 || true
        fi
      }

      case "''${1:-apply}" in
        resolve)
          name="''${2:-}"
          if ! resolve "$name"; then printf '%s\n' "$fallback"; fi
          ;;
        apply)
          name="''${2:-}"
          if [ -z "$name" ]; then
            theme_icons="$HOME/.local/state/theme/current/icons.theme"
            [ -f "$theme_icons" ] && name=$(head -n1 "$theme_icons" | tr -d '[:space:]')
          fi
          name="''${name:-$fallback}"
          resolved=$(resolve "$name" || true)
          if [ -z "$resolved" ]; then
            echo "theme-icons: '$name' is not installed; using $fallback" >&2
            resolved="$fallback"
          fi
          apply_gtk "$resolved"
          ;;
        *)
          echo "usage: theme-icons resolve <name> | apply [name]" >&2
          exit 2
          ;;
      esac
    '';
  };

  themeDms = pkgs.writeShellApplication {
    name = "theme-dms";
    runtimeInputs = [ pkgs.coreutils pkgs.jq pkgs.gawk pkgs.gnused pkgs.glib ];
    text = builtins.readFile ./theme-dms.sh;
  };

  themeSet = pkgs.writeShellApplication {
    name = "theme-set";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.awww
      pkgs.quickshell
      pkgs.procps
      pkgs.findutils
      pkgs.jq
      pkgs.gawk
      pkgs.gnused
      pkgs.git
    ];
    text = ''
      set -eu

      themes_dir=${lib.escapeShellArg themesDir}
      omarchy_themes_dir="$HOME/.config/omarchy/themes"
      state_dir=${lib.escapeShellArg stateDir}
      shell_state="$HOME/.local/state/omarchy/current"
      theme="''${1:-}"

      # Read one scalar from an Omarchy colors.toml. Quoted values are taken
      # verbatim (a hex color starts with '#', which must not be mistaken for
      # a trailing comment); unquoted values lose a trailing comment.
      toml_get() {
        awk -v key="$1" '
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
        ' "$2"
      }

      if [ -z "$theme" ]; then
        echo "usage: theme-set <name>"
        echo "native themes: $(find "$themes_dir" -maxdepth 2 -name palette.json -printf '%h\n' 2>/dev/null | xargs -r -n1 basename | sort | tr '\n' ' ')"
        echo "vendored omarchy themes: $(find "$themes_dir" -maxdepth 2 -name colors.toml -printf '%h\n' 2>/dev/null | xargs -r -n1 basename | sort | tr '\n' ' ')"
        echo "omarchy themes: $(find "$omarchy_themes_dir" -maxdepth 2 -name colors.toml -printf '%h\n' 2>/dev/null | xargs -r -n1 basename | sort | tr '\n' ' ')"
        exit 1
      fi

      theme_path=""
      for base in "$themes_dir" "$omarchy_themes_dir"; do
        if [ -d "$base/$theme" ]; then theme_path="$base/$theme"; break; fi
      done
      if [ -z "$theme_path" ]; then
        echo "theme-set: unknown theme '$theme'" >&2
        exit 1
      fi

      native=0
      [ -f "$theme_path/palette.json" ] && native=1
      if [ "$native" = 0 ] && [ ! -f "$theme_path/colors.toml" ]; then
        echo "theme-set: '$theme_path' has neither palette.json nor colors.toml" >&2
        exit 1
      fi

      icon_theme="Papirus-Dark"
      if [ -f "$theme_path/icons.theme" ]; then
        icon_theme=$(head -n1 "$theme_path/icons.theme" | tr -d '[:space:]')
        [ -n "$icon_theme" ] || icon_theme="Papirus-Dark"
      fi
      icon_theme=$(${themeIcons}/bin/theme-icons resolve "$icon_theme")

      out="$state_dir/generated/$theme"
      rm -rf "$out"
      mkdir -p "$out"

      if [ "$native" = 1 ]; then
        cp -a "$theme_path"/. "$out"/
        palette="$theme_path/palette.json"
        bg=$(jq -r '.bg // "#101315"' "$palette")
        fg=$(jq -r '.fg // "#cacccc"' "$palette")
        accent=$(jq -r '.primary // .secondary // "#cacccc"' "$palette")
        muted=$(jq -r '.fgMuted // "#707880"' "$palette")
        red=$(jq -r '.error // "#a55555"' "$palette")
        orange=$(jq -r '.warning // "#a55555"' "$palette")
        blue=$(jq -r '.info // .primary // "#cacccc"' "$palette")
        green="$accent"
        yellow="$orange"
        cyan="$blue"
        magenta="$accent"
        bright_red="$red"
        bright_green="$green"
        bright_yellow="$yellow"
        bright_blue="$blue"
        bright_magenta="$magenta"
        bright_cyan="$cyan"
      else
        cp "$theme_path/colors.toml" "$out/colors.toml"
        for file in shell.toml niri.kdl gtk.css gtklock.css btop.theme icons.theme; do
          if [ -f "$theme_path/$file" ]; then cp "$theme_path/$file" "$out/$file"; fi
        done
        colors="$theme_path/colors.toml"
        bg=$(toml_get background "$colors"); bg="''${bg:-#101315}"
        fg=$(toml_get foreground "$colors"); fg="''${fg:-#cacccc}"
        accent=$(toml_get accent "$colors"); accent="''${accent:-#cacccc}"
        muted=$(toml_get muted "$colors"); muted="''${muted:-#707880}"
        red=$(toml_get red "$colors"); red="''${red:-#a55555}"
        orange=$(toml_get orange "$colors"); orange="''${orange:-$red}"
        blue=$(toml_get blue "$colors"); blue="''${blue:-$accent}"
        green=$(toml_get green "$colors"); green="''${green:-$accent}"
        yellow=$(toml_get yellow "$colors"); yellow="''${yellow:-$orange}"
        cyan=$(toml_get cyan "$colors"); cyan="''${cyan:-$blue}"
        magenta=$(toml_get magenta "$colors"); magenta="''${magenta:-$accent}"
        bright_red=$(toml_get bright_red "$colors"); bright_red="''${bright_red:-$red}"
        bright_green=$(toml_get bright_green "$colors"); bright_green="''${bright_green:-$green}"
        bright_yellow=$(toml_get bright_yellow "$colors"); bright_yellow="''${bright_yellow:-$yellow}"
        bright_blue=$(toml_get bright_blue "$colors"); bright_blue="''${bright_blue:-$blue}"
        bright_magenta=$(toml_get bright_magenta "$colors"); bright_magenta="''${bright_magenta:-$magenta}"
        bright_cyan=$(toml_get bright_cyan "$colors"); bright_cyan="''${bright_cyan:-$cyan}"
      fi

      if [ ! -f "$out/palette.json" ]; then
        jq -n \
          --arg name "$theme" \
          --arg bg "$bg" --arg fg "$fg" --arg accent "$accent" \
          --arg muted "$muted" --arg red "$red" --arg orange "$orange" \
          --arg blue "$blue" \
          '{name:$name,bg:$bg,surface:$bg,surfaceContainer:$bg,surfaceContainerHigh:$bg,fg:$fg,fgMuted:$muted,primary:$accent,primaryText:$bg,secondary:$accent,outline:$muted,error:$red,warning:$orange,info:$blue}' \
          >"$out/palette.json"
      fi

      if [ ! -f "$out/colors.toml" ]; then
        cat >"$out/colors.toml" <<EOF
      mode = "dark"
      accent = "$accent"
      selection = "$muted"
      muted = "$muted"
      background = "$bg"
      foreground = "$fg"
      red = "$red"
      yellow = "$yellow"
      orange = "$orange"
      green = "$green"
      cyan = "$cyan"
      blue = "$blue"
      magenta = "$magenta"
      EOF
      fi

      if [ ! -f "$out/shell.toml" ]; then
        cat >"$out/shell.toml" <<EOF
      [bar]
      background = "$bg"
      background-alpha = 1.0
      text = "$fg"
      active = "$red"
      scale-with-font = true
      size-horizontal = 30
      size-vertical = 30

      [font]
      base-size = 12

      [spacing]
      scale = 1.0
      scale-with-font = true
      EOF
      fi

      if [ ! -f "$out/niri.kdl" ]; then
        # Inactive borders stay visible but recede, like Omarchy's
        # rgba(595959aa) on Hyprland.
        inactive_color="''${muted}aa"
        cat >"$out/niri.kdl" <<EOF
      layout {
          background-color "transparent"
          focus-ring {
              active-color "$accent"
              inactive-color "$inactive_color"
              urgent-color "$red"
          }
          border {
              active-color "$accent"
              inactive-color "$inactive_color"
              urgent-color "$red"
          }
          shadow {
              color "#00000070"
          }
          tab-indicator {
              active-color "$accent"
              inactive-color "$muted"
              urgent-color "$red"
          }
          insert-hint {
              color "''${accent}80"
          }
      }
      recent-windows {
          highlight {
              active-color "$blue"
              urgent-color "$red"
          }
      }
      EOF
      fi

      if [ ! -f "$out/gtk.css" ]; then
        cat >"$out/gtk.css" <<EOF
      @define-color theme_bg_color $bg;
      @define-color theme_fg_color $fg;
      @define-color theme_base_color $bg;
      @define-color theme_text_color $fg;
      @define-color theme_selected_bg_color $accent;
      @define-color theme_selected_fg_color $bg;
      @define-color accent_color $accent;
      @define-color accent_bg_color $accent;
      @define-color accent_fg_color $bg;
      @define-color window_bg_color $bg;
      @define-color window_fg_color $fg;
      @define-color view_bg_color $bg;
      @define-color view_fg_color $fg;
      @define-color headerbar_bg_color $bg;
      @define-color headerbar_fg_color $fg;
      @define-color card_bg_color $bg;
      @define-color border_color $muted;
      EOF
      fi

      if [ ! -f "$out/gtklock.css" ]; then
        cp "$out/gtk.css" "$out/gtklock.css"
      fi

      if [ ! -f "$out/btop.theme" ]; then
        cat >"$out/btop.theme" <<EOF
      theme[main_bg]="$bg"
      theme[main_fg]="$fg"
      theme[title]="$accent"
      theme[hi_fg]="$accent"
      theme[selected_bg]="$muted"
      theme[selected_fg]="$fg"
      theme[inactive_fg]="$muted"
      theme[graph_text]="$accent"
      theme[meter_bg]="$muted"
      theme[proc_misc]="$accent"
      theme[cpu_box]="$accent"
      theme[mem_box]="$accent"
      theme[net_box]="$accent"
      theme[proc_box]="$accent"
      theme[div_line]="$muted"
      theme[temp_start]="$accent"
      theme[temp_mid]="$orange"
      theme[temp_end]="$red"
      EOF
      fi

      if [ ! -f "$out/ghostty.conf" ]; then
        cat >"$out/ghostty.conf" <<EOF
      background = $bg
      background-opacity = 0.85
      foreground = $fg
      cursor-color = $accent
      cursor-text = $bg
      selection-background = $muted
      selection-foreground = $fg

      palette = 0=$bg
      palette = 1=$red
      palette = 2=$green
      palette = 3=$yellow
      palette = 4=$blue
      palette = 5=$magenta
      palette = 6=$cyan
      palette = 7=$fg
      palette = 8=$muted
      palette = 9=$bright_red
      palette = 10=$bright_green
      palette = 11=$bright_yellow
      palette = 12=$bright_blue
      palette = 13=$bright_magenta
      palette = 14=$bright_cyan
      palette = 15=$fg
      EOF
      fi

      if [ ! -f "$out/foot.ini" ]; then
        plain_bg="''${bg#\#}"
        plain_fg="''${fg#\#}"
        plain_muted="''${muted#\#}"
        cat >"$out/foot.ini" <<EOF
      [main]
      font=JetBrains Mono:size=12
      pad=12x12
      dpi-aware=yes

      [colors-dark]
      alpha=0.95
      background=''${plain_bg}
      foreground=''${plain_fg}
      selection-foreground=''${plain_fg}
      selection-background=''${plain_muted}
      regular0=''${plain_bg}
      regular1=''${red#\#}
      regular2=''${green#\#}
      regular3=''${yellow#\#}
      regular4=''${blue#\#}
      regular5=''${magenta#\#}
      regular6=''${cyan#\#}
      regular7=''${plain_fg}
      bright0=''${plain_muted}
      bright1=''${bright_red#\#}
      bright2=''${bright_green#\#}
      bright3=''${bright_yellow#\#}
      bright4=''${bright_blue#\#}
      bright5=''${bright_magenta#\#}
      bright6=''${bright_cyan#\#}
      bright7=''${plain_fg}

      [csd]
      preferred=none
      size=0
      border-width=0
      EOF
      fi

      # The shell reads theme/colors.toml and theme/shell.toml from this path.
      mkdir -p "$shell_state"
      rm -rf "$shell_state/theme"
      ln -s "$out" "$shell_state/theme"

      # Persist the resolved icon theme in the generated theme.
      printf '%s\n' "$icon_theme" >"$out/icons.theme"

      # Keep app fragments on the stable current path.
      ln -sfn "$out" "$state_dir/current"
      ln -sfn "$state_dir/current/niri.kdl" ${lib.escapeShellArg repoThemeLink}
      ${themeDms}/bin/theme-dms || true
      # Niri reloads when a watched file changes; replacing the theme symlink
      # alone does not fire an inotify event, so bump the resolved target.
      touch "$HOME/.config/niri/theme.kdl" 2>/dev/null || true

      ${themeIcons}/bin/theme-icons apply "$icon_theme" || true

      if [ -d "$theme_path/backgrounds" ]; then
        rm -rf "$out/wallpapers"
        ln -s "$theme_path/backgrounds" "$out/wallpapers"
      elif [ -d "$theme_path/wallpapers" ] && [ ! -L "$out/wallpapers" ]; then
        rm -rf "$out/wallpapers"
        ln -s "$theme_path/wallpapers" "$out/wallpapers"
      fi

      bg=$(find -L "$out/wallpapers" -maxdepth 1 -type f 2>/dev/null | sort | head -n1 || true)
      if [ -n "''${bg:-}" ]; then
        if ! pgrep -f 'awww-daemon' >/dev/null 2>&1; then
          awww-daemon --format xrgb >/dev/null 2>&1 &
          sleep 0.5
        fi
        awww img "$bg" --transition-type random --transition-duration 0.8 >/dev/null 2>&1 || true
      fi

      # Runtime theme switch: the shell does not watch colors.toml/shell.toml,
      # so push both payloads through the IPC applyTheme handler. Prefer the
      # config path of the actually running shell process: after a rebuild the
      # deployed omarchy-ipc can point at a generation the shell is not using.
      shell_ipc() {
        local pid cfg
        for pid in $(pgrep -f 'quickshell -p .*omarchy/shell' 2>/dev/null || true); do
          cfg=$(tr '\0' '\n' <"/proc/$pid/cmdline" 2>/dev/null | awk 'prev=="-p" { print; exit } { prev=$0 }')
          if [ -n "$cfg" ] && quickshell ipc -p "$cfg" call shell ping >/dev/null 2>&1; then
            quickshell ipc -p "$cfg" "$@" >/dev/null 2>&1 || true
            return 0
          fi
        done
        if command -v omarchy-ipc >/dev/null 2>&1; then
          omarchy-ipc "$@" >/dev/null 2>&1 || true
        elif command -v quickshell >/dev/null 2>&1; then
          quickshell ipc "$@" >/dev/null 2>&1 || true
        fi
      }

      colors_payload=$(base64 -w0 <"$out/colors.toml")
      shell_payload=$(base64 -w0 <"$out/shell.toml")
      shell_ipc call shell applyTheme "$colors_payload" "$shell_payload"
      echo "theme: $theme"
    '';
  };

  themeInstall = pkgs.writeShellApplication {
    name = "theme-install";
    runtimeInputs = [ pkgs.coreutils pkgs.git pkgs.gnused pkgs.gum ];
    text = ''
      set -eu

      refuse() {
        echo "theme-install: $*" >&2
        exit 1
      }

      url="''${1:-}"
      if [ -z "$url" ]; then
        url=$(gum input \
          --header "Install an Omarchy theme" \
          --placeholder "https://github.com/<owner>/omarchy-<name>-theme" \
          --prompt "Theme git URL> " </dev/tty || true)
      fi
      [ -n "''${url:-}" ] || exit 1

      # git runs a remote helper for `<helper>::<address>` and for schemes it
      # does not handle itself. Refuse the helper form outright and allowlist
      # the transports a theme repository can legitimately use; ext:: would
      # execute a command. Ported from upstream omarchy-git-url-check.
      case "$url" in
        -*) refuse "'$url' names a git option, not a repository." ;;
      esac
      if [[ $url =~ ^[A-Za-z0-9][A-Za-z0-9+.-]*:: ]]; then
        refuse "'$url' names a git transport helper, not a repository."
      fi
      if [[ $url =~ ^([A-Za-z0-9][A-Za-z0-9+.-]*):// ]]; then
        scheme=$(printf '%s' "''${BASH_REMATCH[1]}" | tr '[:upper:]' '[:lower:]')
        case "$scheme" in
          ssh|git|git+ssh|ssh+git|http|https|ftp|ftps|file) ;;
          *) refuse "'$url' uses the '$scheme' transport, which theme-install does not clone from." ;;
        esac
      fi

      themes_dir="$HOME/.config/omarchy/themes"

      # Strip a user@host: prefix from scp-style SSH URLs so basename sees
      # just the repository path. A single colon before any slash is ssh,
      # not a URL scheme.
      repo_path="$url"
      if [[ $repo_path != *"://"* && $repo_path == *:* && ''${repo_path%%:*} != */* ]]; then
        repo_path="''${repo_path#*:}"
      fi
      name=$(basename -- "$repo_path" .git | sed -E 's/^omarchy-//; s/-theme$//' | tr '[:upper:]' '[:lower:]')
      # Pin the collation: [a-z] would otherwise accept accented letters.
      ( LC_ALL=C; [[ $name =~ ^[a-z0-9_][a-z0-9._+-]*$ ]] ) || \
        refuse "'$url' does not give a usable theme name."

      mkdir -p "$themes_dir"

      # Clone beside the target and swap only after colors.toml is present, so
      # a failed clone or a non-theme repository never destroys an installed
      # theme. --depth 1 keeps the wallpaper-heavy repositories small.
      tmp=$(mktemp -d "$themes_dir/.install.XXXXXX")
      trap 'rm -rf "$tmp"' EXIT
      if ! git clone --depth 1 -- "$url" "$tmp/theme"; then
        refuse "failed to clone $url"
      fi
      if [ ! -f "$tmp/theme/colors.toml" ]; then
        refuse "$url does not look like an Omarchy theme (no colors.toml)."
      fi

      rm -rf "''${themes_dir:?}/''${name:?}"
      mv "$tmp/theme" "$themes_dir/$name"
      trap - EXIT
      rm -rf "$tmp"

      theme-set "$name"
      printf 'theme-installed %s\n' "$name"
    '';
  };


  # Data for the theme and wallpaper carousels. One source of truth for the
  # lists both the gallery overlay and the shell need, so the carousel order
  # matches bg-cycle exactly.
  gallery = pkgs.writeShellApplication {
    name = "omarchy-gallery";
    runtimeInputs = [ pkgs.coreutils pkgs.findutils pkgs.jq pkgs.awww pkgs.procps themeSet ];
    text = ''
      set -euo pipefail
      state_dir=${lib.escapeShellArg stateDir}
      themes_dir=${lib.escapeShellArg themesDir}
      omarchy_themes_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/themes"

      current=$(basename "$(readlink -f "$state_dir/current")")

      first_image() {
        local dir=$1
        [ -d "$dir" ] || return 0
        find -L "$dir" -maxdepth 1 -type f \
          \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
          2>/dev/null | sort | head -n1 || true
      }

      theme_entry() {
        local path=$1 name=$2 kind=native preview="" bg="" fg="" accent="" candidate
        [ -f "$path/palette.json" ] || kind=omarchy
        for candidate in preview.png preview.webp preview.jpg; do
          if [ -f "$path/$candidate" ]; then preview="$path/$candidate"; break; fi
        done
        [ -n "$preview" ] || preview=$(first_image "$path/backgrounds")
        [ -n "$preview" ] || preview=$(first_image "$path/wallpapers")
        if [ -f "$path/palette.json" ]; then
          bg=$(jq -r '.bg // empty' "$path/palette.json")
          fg=$(jq -r '.fg // empty' "$path/palette.json")
          accent=$(jq -r '.primary // .secondary // empty' "$path/palette.json")
        elif [ -f "$path/colors.toml" ]; then
          bg=$(awk -F'"' '/^background[[:space:]]*=/{print $2; exit}' "$path/colors.toml")
          fg=$(awk -F'"' '/^foreground[[:space:]]*=/{print $2; exit}' "$path/colors.toml")
          accent=$(awk -F'"' '/^accent[[:space:]]*=/{print $2; exit}' "$path/colors.toml")
        fi
        jq -cn --arg name "$name" --arg kind "$kind" --arg preview "$preview" \
          --arg bg "$bg" --arg fg "$fg" --arg accent "$accent" \
          '{name:$name,kind:$kind,preview:$preview,bg:$bg,fg:$fg,accent:$accent}'
      }

      list_themes() {
        local entries=() dir name
        for dir in "$themes_dir"/*/; do
          [ -d "$dir" ] || continue
          [ -f "$dir/palette.json" ] || [ -f "$dir/colors.toml" ] || continue
          name=$(basename "$dir")
          entries+=("$(theme_entry "''${dir%/}" "$name")")
        done
        for dir in "$omarchy_themes_dir"/*/; do
          [ -d "$dir" ] || continue
          [ -f "$dir/colors.toml" ] || continue
          name=$(basename "$dir")
          [ -e "$themes_dir/$name" ] && continue
          entries+=("$(theme_entry "''${dir%/}" "$name")")
        done
        if [ ''${#entries[@]} -eq 0 ]; then
          jq -cn --arg current "$current" '{current:$current, items:[]}'
          return
        fi
        printf '%s\n' "''${entries[@]}" | jq -sc --arg current "$current" '{current:$current, items:.}'
      }

      wallpaper_files() {
        local dir="$state_dir/current/wallpapers"
        [ -d "$dir" ] || dir="$HOME/Pictures/Wallpapers"
        find -L "$dir" -maxdepth 1 -type f \
          \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
          2>/dev/null | sort || true
      }

      list_wallpapers() {
        local files=() file index=0
        while IFS= read -r file; do files+=("$file"); done < <(wallpaper_files)
        [ -f "$state_dir/wallpaper.idx" ] && index=$(cat "$state_dir/wallpaper.idx" 2>/dev/null || echo 0)
        if [ ''${#files[@]} -eq 0 ]; then
          printf '%s\n' '{"index":0,"items":[]}'
          return
        fi
        printf '%s\n' "''${files[@]}" | jq -Rsc --argjson index "$index" \
          '{index:($index | tonumber? // 0), items:(split("\n") | map(select(length > 0)))}'
      }

      set_wallpaper() {
        local want=$1 files=() file index=0
        while IFS= read -r file; do files+=("$file"); done < <(wallpaper_files)
        [ ''${#files[@]} -gt 0 ] || { echo "omarchy-gallery: no wallpapers" >&2; exit 1; }
        index=$want
        { [ "$index" -ge 0 ] && [ "$index" -lt ''${#files[@]} ]; } || exit 1
        echo "$index" >"$state_dir/wallpaper.idx"
        if ! pgrep -f 'awww-daemon' >/dev/null 2>&1; then
          awww-daemon --format xrgb >/dev/null 2>&1 &
          sleep 0.5
        fi
        awww img "''${files[$index]}" --transition-type random --transition-duration 0.8
      }

      case "''${1:-}" in
        themes) list_themes ;;
        wallpapers) list_wallpapers ;;
        theme)
          [ $# -eq 2 ] || { echo "usage: omarchy-gallery theme <name>" >&2; exit 2; }
          exec ${themeSet}/bin/theme-set "$2"
          ;;
        wallpaper)
          [ $# -eq 2 ] || { echo "usage: omarchy-gallery wallpaper <index>" >&2; exit 2; }
          set_wallpaper "$2"
          ;;
        *)
          echo "usage: omarchy-gallery themes|wallpapers|theme <name>|wallpaper <index>" >&2
          exit 2
          ;;
      esac
    '';
  };

  bgCycle = pkgs.writeShellApplication {
    name = "bg-cycle";
    runtimeInputs = [ pkgs.coreutils pkgs.awww pkgs.findutils ];
    text = ''
      set -eu
      step="''${1:-next}"
      state_dir=${lib.escapeShellArg stateDir}
      dir="$state_dir/current/wallpapers"
      [ -d "$dir" ] || dir="$HOME/Pictures/Wallpapers"
      mapfile -t files < <(find "$dir" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort)
      [ "''${#files[@]}" -gt 0 ] || { echo "bg-cycle: no wallpapers in $dir" >&2; exit 1; }

      idx_file="$state_dir/wallpaper.idx"
      idx=0
      [ -f "$idx_file" ] && idx=$(cat "$idx_file" 2>/dev/null || echo 0)
      if [ "$step" = "prev" ]; then idx=$(( (idx - 1 + ''${#files[@]}) % ''${#files[@]} )); else idx=$(( (idx + 1) % ''${#files[@]} )); fi
      echo "$idx" > "$idx_file"

      if ! pgrep -f 'awww-daemon' >/dev/null 2>&1; then
        awww-daemon --format xrgb >/dev/null 2>&1 &
        sleep 0.5
      fi
      awww img "''${files[$idx]}" --transition-type random --transition-duration 0.8
    '';
  };

  bgNext = pkgs.writeShellApplication {
    name = "bg-next";
    runtimeInputs = [ bgCycle ];
    text = ''bg-cycle next'';
  };

  bgPrev = pkgs.writeShellApplication {
    name = "bg-prev";
    runtimeInputs = [ bgCycle ];
    text = ''bg-cycle prev'';
  };
in
{
  options.mySystem.theme = {
    name = mkOption {
      type = types.enum available;
      default = "dankViolet";
      description = "Активная тема из home-manager/modules/desktop/themes.";
    };
    package = mkOption {
      type = types.package;
      default = themeSet;
      internal = true;
    };
  };

  config = {
    home.packages = [
      themeSet
      themeIcons
      themeDms
      gallery
      themeInstall
      bgCycle
      bgNext
      bgPrev
      pkgs.awww
      pkgs.waypaper
    ];

    # Все приложения читают файлы через стабильный `current`, который
    # переключает theme-set.
    xdg.configFile = {
      "theme/palette.json".source = mkLink "${current}/palette.json";
      "niri/theme.kdl".source = mkLink "${current}/niri.kdl";
      "btop/themes/current.theme".source = mkLink "${current}/btop.theme";
      "gtklock/style.css".source = mkLink "${current}/gtklock.css";
      "gtk-3.0/gtk.css".source = mkLink "${current}/gtk.css";
      "gtk-4.0/gtk.css".source = mkLink "${current}/gtk.css";
      "foot/foot.ini".source = mkLink "${current}/foot.ini";
    };

    # Дефолтная тема при первом деплое: создаём current, если его нет.
    home.activation.themeInit = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run mkdir -p ${lib.escapeShellArg stateDir}
      if [ ! -e ${lib.escapeShellArg current} ]; then
        run ln -sfn ${lib.escapeShellArg "${themesDir}/${cfg.name}"} ${lib.escapeShellArg current}
      fi
      run ln -sfn ${lib.escapeShellArg "${current}/niri.kdl"} ${lib.escapeShellArg repoThemeLink}
    '';

    # gtk.iconTheme is static in Nix; re-apply the active theme's icons after
    # Home Manager links its settings.ini on every activation/login.
    home.activation.themeIcons = lib.hm.dag.entryAfter [ "linkGeneration" "themeInit" ] ''
      run ${themeIcons}/bin/theme-icons apply || true
    '';

    # Publish the active palette for Dux Files (it reads the DMS cache) and
    # keep the portal colour scheme in sync with dark/light themes.
    home.activation.themeDms = lib.hm.dag.entryAfter [ "linkGeneration" "themeInit" "themeIcons" ] ''
      run ${themeDms}/bin/theme-dms || true
    '';

    xdg.configFile."btop/btop.conf".text = ''
      color_theme = "current"
      theme_background = false
      truecolor = true
      rounded_corners = true
      update_ms = 1000
      proc_sorting = "cpu lazy"
      shown_boxes = "cpu mem net proc"
    '';

    xdg.configFile."waypaper/config.ini".text = ''
      [Settings]
      language = en
      folder = ${config.home.homeDirectory}/Pictures/Wallpapers
      backend = awww
      monitors = All
      fill = fill
      sort = name
      color = #090415
      subfolders = false
      show_path = false
      show_hidden = false
      use_xdg_state = false
      swallow = false
    '';

    systemd.user.services.swww = {
      Unit = {
        Description = "swww wallpaper daemon";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.awww}/bin/awww-daemon --format xrgb";
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
