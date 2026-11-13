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
# fuzzel.ini, btop.theme), переключает симлинки и отдаёт новые цвета живой
# оболочке через IPC applyTheme. Пересборка не нужна; fuzzel/btop/gtklock/GTK
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
        for file in shell.toml niri.kdl gtk.css gtklock.css fuzzel.ini btop.theme; do
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
        cat >"$out/niri.kdl" <<EOF
      layout {
          background-color "transparent"
          focus-ring {
              active-color "$accent"
              inactive-color "$muted"
              urgent-color "$red"
          }
          border {
              active-color "$accent"
              inactive-color "$muted"
              urgent-color "$red"
          }
          shadow { color "#00000070" }
          tab-indicator {
              active-color "$accent"
              inactive-color "$muted"
              urgent-color "$red"
          }
          insert-hint { color "''${accent}80" }
      }
      recent-windows {
          highlight { active-color "$blue"; urgent-color "$red" }
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

      if [ ! -f "$out/fuzzel.ini" ]; then
        bghex="''${bg#\#}"
        fghex="''${fg#\#}"
        accenthex="''${accent#\#}"
        mutedhex="''${muted#\#}"
        cat >"$out/fuzzel.ini" <<EOF
      [main]
      font=JetBrains Mono:size=11
      prompt="  "
      icons-enabled=yes
      terminal=ghostty
      lines=12
      width=48
      horizontal-pad=16
      vertical-pad=12
      inner-pad=10

      [colors]
      background=''${bghex}f2
      text=''${fghex}ff
      prompt=''${accenthex}ff
      input=''${fghex}ff
      match=''${accenthex}ff
      selection=''${mutedhex}ff
      selection-text=''${fghex}ff
      selection-match=''${accenthex}ff
      border=''${mutedhex}ff

      [border]
      width=1
      radius=12
      EOF
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
      app-id=org.omarchy.transient

      [colors]
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
      EOF
      fi

      # The shell reads theme/colors.toml and theme/shell.toml from this path.
      mkdir -p "$shell_state"
      rm -rf "$shell_state/theme"
      ln -s "$out" "$shell_state/theme"

      # Keep app fragments on the stable current path.
      ln -sfn "$out" "$state_dir/current"
      ln -sfn "$state_dir/current/niri.kdl" ${lib.escapeShellArg repoThemeLink}

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
    runtimeInputs = [ pkgs.coreutils pkgs.git pkgs.gnused ];
    text = ''
      set -eu
      url="''${1:-}"
      if [ -z "$url" ]; then
        echo "usage: theme-install <git-url>" >&2
        exit 1
      fi
      themes_dir="$HOME/.config/omarchy/themes"
      name=$(basename -- "''${url%.git}" | sed -E 's/^omarchy-//; s/-theme$//' | tr '[:upper:]' '[:lower:]')
      [[ $name =~ ^[a-z0-9_][a-z0-9._+-]*$ ]] || {
        echo "theme-install: unusable theme name '$name'" >&2
        exit 1
      }
      mkdir -p "$themes_dir"
      rm -rf "''${themes_dir:?}/''${name:?}"
      git clone -- "$url" "$themes_dir/$name"
      exec theme-set "$name"
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
      "fuzzel/fuzzel.ini".source = mkLink "${current}/fuzzel.ini";
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
