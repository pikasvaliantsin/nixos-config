{ config, pkgs, inputs, ... }:

{
  # ============================================
  # FLATPAK (через nix-flatpak)
  # ============================================

  services.flatpak = {
    enable = true;

    # Репозитории
    remotes = [
      {
        name = "flathub";
        location = "https://flathub.org/repo/flathub.flatpakrepo";
      }
      # Если нужно beta:
      # {
      #   name = "flathub-beta";
      #   location = "https://flathub.org/beta-repo/flathub-beta.flatpakrepo";
      # }
    ];

    # Приложения
    packages = [
      # Простой формат (имя приложения, origin по умолчанию — flathub)
      # "com.brave.Browser"
      # "im.riot.Riot"
      # "org.mozilla.firefox"

      # Или с явным указанием origin и коммита
      # {
      #   appId = "com.spotify.Client";
      #   origin = "flathub";
      #   commit = "abc123...";  # опционально
      # }

      # Для PortProton — уточни точное название
      "ru.linux_gaming.PortProton"
    ];

    # Автообновление при активации (опционально)
    update.onActivation = false;  # или true, если хочешь автообновление
  };
}
