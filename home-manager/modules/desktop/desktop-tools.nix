# Рабочие утилиты десктопа: буфер обмена, launcher, lock, звук.
# Сам бар живёт в omarchy.nix; старый конфиг Quickshell убран в legacy/.
{ config, pkgs, ... }:

let
  home = config.home.homeDirectory;

  # Сбор истории буфера в стиле omarchy: текст — инлайном, картинки — файлами,
  # всё в JSON. Скрипт вызывается watcher'ами wl-paste.
  clipCapture = pkgs.writeShellApplication {
    name = "clip-capture";
    runtimeInputs = [ pkgs.coreutils pkgs.jq pkgs.wl-clipboard pkgs.util-linux ];
    text = ''
      set -euo pipefail
      mime="''${1:-}"
      [ -n "$mime" ] || exit 1

      state="$HOME/.local/state/quickshell/clipboard"
      img="$state/images"
      mkdir -p "$img"

      if wl-paste --list-types 2>/dev/null | grep -qx 'x-kde-passwordManagerHint'; then
        exit 0
      fi

      tmp=$(mktemp)
      trap 'rm -f "$tmp"' EXIT
      if ! timeout 2 cat > "$tmp"; then
        exit 0
      fi
      [ -s "$tmp" ] || exit 0

      hist="$state/history.json"
      [ -f "$hist" ] || printf '[]\n' > "$hist"

      entry=""
      case "$mime" in
        image/*)
          hash=$(sha256sum "$tmp" | cut -d' ' -f1)
          ext="''${mime#image/}"
          [ "$ext" = "jpeg" ] && ext="jpg"
          file="$img/$hash.$ext"
          if [ ! -e "$file" ]; then mv "$tmp" "$file"; fi
          entry=$(jq -cn --arg mime "$mime" --arg path "$file" --arg at "$(date +%H:%M)" \
            '{type:"image", mime:$mime, path:$path, capturedAt:$at}')
          ;;
        text)
          entry=$(jq -n --rawfile t "$tmp" --arg at "$(date +%H:%M)" \
            '{type:"text", text:$t, capturedAt:$at}')
          ;;
        *) exit 0 ;;
      esac

      (
        flock 9
        jq --argjson e "$entry" '
          (first(.[] | select(
            if $e.type == "image" then (.type == "image" and .path == $e.path)
            else (.type == "text" and .text == $e.text)
            end
          ) | .pinned) // false) as $pinned
          | ([ ($e + (if $pinned then {pinned: true} else {} end)) ]
             + [ .[] | select(
                 if $e.type == "image" then (.type != "image" or .path != $e.path)
                 else (.type != "text" or .text != $e.text)
                 end
               ) ]) as $merged
          | ([ $merged[] | select(.pinned) ] + ([ $merged[] | select(.pinned | not) ][0:200]))
        ' "$hist" > "$hist.tmp"
        mv "$hist.tmp" "$hist"
      ) 9>"$state/.lock"
    '';
  };

  # Copy one history entry back to the Wayland clipboard. The QML panel passes
  # the history index so long text is read from JSON, not from its capped
  # row preview.
  clipCopy = pkgs.writeShellApplication {
    name = "clipboard-copy";
    runtimeInputs = [ pkgs.coreutils pkgs.jq pkgs.wl-clipboard ];
    text = ''
      set -euo pipefail
      idx="''${1:-}"
      [[ $idx =~ ^[0-9]+$ ]] || {
        echo "usage: clipboard-copy <history-index>" >&2
        exit 2
      }
      hist="$HOME/.local/state/quickshell/clipboard/history.json"
      [ -f "$hist" ] || exit 1

      kind=$(jq -r --argjson i "$idx" '.[$i].type // empty' "$hist")
      case "$kind" in
        text)
          jq -j --argjson i "$idx" '.[$i].text // ""' "$hist" | wl-copy
          ;;
        image)
          mime=$(jq -r --argjson i "$idx" '.[$i].mime // "image/png"' "$hist")
          path=$(jq -r --argjson i "$idx" '.[$i].path // empty' "$hist")
          [ -n "$path" ] && [ -f "$path" ] || exit 1
          wl-copy --type "$mime" < "$path"
          ;;
        *) exit 1 ;;
      esac
    '';
  };

  lastShot = pkgs.writeShellApplication {
    name = "last-shot";
    runtimeInputs = [ pkgs.coreutils pkgs.findutils pkgs.wl-clipboard pkgs.libnotify ];
    text = ''
      set -euo pipefail
      f=$(find "$HOME/Pictures/Screenshots" -maxdepth 1 -type f -name '*.png' -printf '%T@ %p\n' 2>/dev/null \
        | sort -rn | head -n1 | cut -d' ' -f2- || true)
      if [ -z "''${f:-}" ]; then
        notify-send "Скриншот" "Нет файлов в ~/Pictures/Screenshots"
        exit 1
      fi
      wl-copy --type image/png < "$f"
      notify-send "Скриншот" "Скопирован: $(basename "$f")"
    '';
  };

  shotPath = pkgs.writeShellApplication {
    name = "shot-path";
    runtimeInputs = [ pkgs.coreutils pkgs.grim pkgs.slurp pkgs.wl-clipboard pkgs.libnotify ];
    text = ''
      set -euo pipefail
      dir="$HOME/Pictures/Screenshots"
      mkdir -p "$dir"
      f="$dir/$(date +%F_%H-%M-%S).png"
      grim -g "$(slurp)" "$f"
      printf '%s' "$f" | wl-copy
      notify-send "Скриншот" "Путь скопирован: $f"
    '';
  };
in
{
  home.packages = with pkgs; [
    quickshell
    walker
    elephant
    swayosd
    gtklock
    awww
    waypaper
    satty
    btop
    impala
    bluetui
    wiremix
    playerctl
    wlogout
    brightnessctl
    libnotify
    calcurse
    grim
    slurp
    curl
    lastShot
    shotPath
    clipCapture
    clipCopy
  ];

  # Два watcher'а: текст и PNG. Пишут в ~/.local/state/quickshell/clipboard.
  systemd.user.services.clipboard-text = {
    Unit = {
      Description = "Clipboard history: text";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${clipCapture}/bin/clip-capture text";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.clipboard-image = {
    Unit = {
      Description = "Clipboard history: images";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type image/png --watch ${clipCapture}/bin/clip-capture image/png";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  xdg.configFile."gtklock/config.ini".text = ''
    [main]
    lock-command=gtklock
  '';

  # Walker + Elephant: лаунчер и провайдеры (приложения, буфер, файлы, окна).
  # Конфиг лежит в репозитории, правки подхватываются без пересборки.
  xdg.configFile."walker/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${config.mySystem.dotfilesRoot}/home-manager/modules/desktop/walker/config.toml";

  systemd.user.services.elephant = {
    Unit = {
      Description = "Elephant provider service";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.elephant}/bin/elephant";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.walker = {
    Unit = {
      Description = "Walker launcher service";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" "elephant.service" ];
      Wants = [ "elephant.service" ];
    };
    Service = {
      ExecStart = "${pkgs.walker}/bin/walker --gapplication-service";
      Restart = "on-failure";
      RestartSec = 2;
      Environment = [
        "PATH=${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
      ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  home.activation.quickshellState = config.lib.dag.entryAfter [ "linkGeneration" ] ''
    run mkdir -p "${home}/.local/state/quickshell"
    run mkdir -p "${home}/.local/state/quickshell/clipboard/images"
  '';
}
