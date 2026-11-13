# Quickshell-бар + сопутствующие утилиты.
{ config, pkgs, ... }:

let
  home = config.home.homeDirectory;

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
    fuzzel
    cliphist
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
  ];

  services.cliphist = {
    enable = true;
    allowImages = true;
  };

  # Конфиг бара живёт в репозитории: правки видны без пересборки.
  xdg.configFile."quickshell".source =
    config.lib.file.mkOutOfStoreSymlink "${config.mySystem.dotfilesRoot}/home-manager/modules/desktop/quickshell";

  xdg.configFile."gtklock/config.ini".text = ''
    [main]
    lock-command=gtklock
  '';

  systemd.user.services.quickshell = {
    Unit = {
      Description = "Quickshell desktop shell";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.quickshell}/bin/quickshell";
      Restart = "on-failure";
      RestartSec = 2;
      Environment = [ "QT_QPA_PLATFORM=wayland" ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  home.activation.quickshellState = config.lib.dag.entryAfter [ "linkGeneration" ] ''
    run mkdir -p "${home}/.local/state/quickshell"
    run mkdir -p "${home}/.cache/quickshell/clip"
  '';
}
