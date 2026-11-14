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

  # Read image dimensions without decoding the bitmap. Used by the clipboard
  # panel to scale its floating preview against the current monitor.
  imageSize = pkgs.writeShellApplication {
    name = "image-size";
    runtimeInputs = [ pkgs.coreutils pkgs.file pkgs.gnugrep ];
    text = ''
      set -euo pipefail
      path="''${1:-}"
      [ -f "$path" ] || exit 1
      file -b -- "$path" \
        | grep -oE '[0-9]+[[:space:]]*x[[:space:]]*[0-9]+' \
        | tail -n1 \
        | tr -d '[:space:]' \
        | tr 'x' ' '
    '';
  };

  # Remove clipboard images that no longer appear in history, and keep the
  # image directory under a size ceiling by dropping the oldest unpinned
  # image entries. Pinned entries and their files are never removed.
  clipGc = pkgs.writeShellApplication {
    name = "clipboard-gc";
    runtimeInputs = [ pkgs.coreutils pkgs.jq pkgs.findutils pkgs.gnugrep pkgs.util-linux ];
    text = ''
      set -euo pipefail

      state="''${CLIPBOARD_GC_STATE_DIR:-''${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/clipboard}"
      max_bytes="''${CLIPBOARD_GC_MAX_BYTES:-1073741824}"
      hist="$state/history.json"
      images="$state/images"

      [ -f "$hist" ] || exit 0
      [ -d "$images" ] || exit 0
      mkdir -p "$state"

      # Capture and GC share this lock, so a new clip cannot land between the
      # reference list and the deletions.
      exec 9>"$state/.lock"
      flock 9

      # A malformed history must never be treated as "everything is orphaned".
      if ! jq -e 'type == "array"' "$hist" >/dev/null; then
        echo "clipboard-gc: invalid history file, leaving images untouched" >&2
        exit 1
      fi

      refs=$(mktemp)
      tmp=$(mktemp)
      trap 'rm -f "$refs" "$tmp"' EXIT

      jq -r '.[]? | select(.type == "image") | .path // empty' "$hist" >"$refs"

      removed_files=0
      while IFS= read -r -d $'\0' file; do
        if ! grep -qxF -- "$file" "$refs"; then
          rm -f -- "$file"
          removed_files=$((removed_files + 1))
        fi
      done < <(find "$images" -maxdepth 1 -type f -print0)

      removed_entries=0
      while :; do
        total=$(du -sb "$images" | cut -f1)
        [ "$total" -le "$max_bytes" ] && break

        idx=$(jq -r 'to_entries | map(select((.value.pinned // false) != true and .value.type == "image")) | last | .key // empty' "$hist")
        if [ -z "$idx" ]; then
          echo "clipboard-gc: $((total / 1048576)) MiB used, over the limit only because of pinned entries" >&2
          break
        fi

        path=$(jq -r --argjson i "$idx" '.[$i].path // empty' "$hist")
        jq --argjson i "$idx" 'del(.[$i])' "$hist" >"$tmp"
        mv "$tmp" "$hist"
        removed_entries=$((removed_entries + 1))

        if [ -n "$path" ]; then
          still=$(jq -r --arg p "$path" '[.[]? | select(.type == "image" and .path == $p)] | length' "$hist")
          case "$path" in
            "$images"/*)
              if [ "$still" = "0" ]; then rm -f -- "$path"; fi
              ;;
          esac
        fi
      done

      remaining=$(( $(du -sb "$images" | cut -f1) / 1048576 ))
      echo "clipboard-gc: removed ''${removed_files} orphan files, ''${removed_entries} old entries; ''${remaining} MiB remain"
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
    swayosd
    gtklock
    awww
    waypaper
    satty
    btop
    libqalculate
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
    imageSize
    clipGc
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

  systemd.user.services.clipboard-gc = {
    Unit = {
      Description = "Clipboard history garbage collection";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${clipGc}/bin/clipboard-gc";
      Nice = 10;
    };
  };

  systemd.user.timers.clipboard-gc = {
    Unit = {
      Description = "Daily clipboard history garbage collection";
    };
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "10min";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  xdg.configFile."gtklock/config.ini".text = ''
    [main]
    lock-command=gtklock
  '';

  home.activation.quickshellState = config.lib.dag.entryAfter [ "linkGeneration" ] ''
    run mkdir -p "${home}/.local/state/quickshell"
    run mkdir -p "${home}/.local/state/quickshell/clipboard/images"
  '';
}
