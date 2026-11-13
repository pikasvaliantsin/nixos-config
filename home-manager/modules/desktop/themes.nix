# Система тем: один каталог темы — фрагменты для всего стека.
#
# Активная тема указывает на каталог в репозитории через
# ~/.local/state/theme/current, поэтому `theme-set <name>` переключает всё
# без пересборки: niri (автоперечитывает конфиг), Quickshell (IPC reload),
# fuzzel/btop/gtklock/GTK подхватят при следующем запуске.
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
    runtimeInputs = [ pkgs.coreutils pkgs.awww pkgs.quickshell pkgs.procps pkgs.findutils ];
    text = ''
      set -eu
      themes_dir=${lib.escapeShellArg themesDir}
      state_dir=${lib.escapeShellArg stateDir}
      theme="''${1:-}"
      if [ -z "$theme" ]; then
        echo "usage: theme-set <name>"
        echo "available: $(find "$themes_dir" -maxdepth 2 -name palette.json -printf '%h\n' | xargs -n1 basename | sort | tr '\n' ' ')"
        exit 1
      fi
      if [ ! -f "$themes_dir/$theme/palette.json" ]; then
        echo "theme-set: unknown theme '$theme'" >&2
        exit 1
      fi

      mkdir -p "$state_dir"
      ln -sfn "$themes_dir/$theme" "$state_dir/current"
      ln -sfn "$state_dir/current/niri.kdl" ${lib.escapeShellArg repoThemeLink}

      bg=$(find "$themes_dir/$theme/wallpapers" -maxdepth 1 -type f 2>/dev/null | sort | head -n1 || true)
      if [ -n "''${bg:-}" ]; then
        if ! pgrep -x awww-daemon >/dev/null 2>&1; then
          awww-daemon --format xrgb >/dev/null 2>&1 &
          sleep 0.5
        fi
        awww img "$bg" --transition-type random --transition-duration 0.8 >/dev/null 2>&1 || true
      fi

      quickshell ipc call shell reloadConfig >/dev/null 2>&1 || true
      echo "theme: $theme"
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

      if ! pgrep -x awww-daemon >/dev/null 2>&1; then
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
