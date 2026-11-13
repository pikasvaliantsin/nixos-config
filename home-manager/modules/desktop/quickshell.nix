# Quickshell-бар + сопутствующие утилиты.
{ config, pkgs, ... }:

let
  home = config.home.homeDirectory;
in
{
  home.packages = with pkgs; [
    quickshell
    fuzzel
    cliphist
    swayosd
    gtklock
    swww
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
    curl
  ];

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
  '';
}
