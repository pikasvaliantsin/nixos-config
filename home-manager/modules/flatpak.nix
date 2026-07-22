{ config, pkgs, ... }:

{
  # ============================================
  # FLATPAK
  # ============================================

  # 1. Включаем управление Flatpak через Home Manager
  services.flatpak = {
    enableModule = true;  # Включает управление пакетами

    # 2. Список Flatpak-приложений для установки
    packages = [
      # Браузеры
      # "org.mozilla.firefox"
      # "com.brave.Browser"

      # Мессенджеры
      # "im.riot.Riot"        # Element
      # "com.discordapp.Discord"

      # Утилиты
      # "org.onlyoffice.desktopeditors"
      # "com.spotify.Client"

      # (добавляй сюда свои приложения)
      PortProton
    ];
  };

  # 3. Добавляем репозиторий Flathub (через xdg.dataFile, т.к. в Home Manager нет опции remotes)
  xdg.dataFile."flatpak/remotes.d/flathub.flatpakrepo".text = ''
    [Flathub]
    Url=https://flathub.org/repo/flathub.flatpakrepo
    Title=Flathub
    Comment=Central repository of Flatpak applications
    Homepage=https://flathub.org
  '';
}
