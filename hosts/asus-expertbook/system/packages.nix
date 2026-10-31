{ pkgs, ... }:

{
  # Минимальный набор пакетов, доступных root и в rescue-сессии.
  # Пользовательские приложения ставятся через home-manager.
  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    gsettings-desktop-schemas
    btrfs-progs
  ];
}
