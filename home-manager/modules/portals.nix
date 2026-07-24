{config, pkgs, ...}:

{
    xdg.portal = {
      enable = true;
      
      # Подключаем нужные порталы, как в доках Niri
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
        xdg-desktop-portal-gnome
        gnome-keyring
      ];

      # Указываем пакеты, конфиги которых нужно использовать
      configPackages = with pkgs; [
        xdg-desktop-portal-gtk
        xdg-desktop-portal-gnome
        niri # Сам Niri тоже должен быть в configPackages для своих специфичных вещей
      ];

      # Конфигурация порталов (аналог niri-portals.conf)
      config = {
        common.default = "*"; # Fallback на GTK
        # Если не хочешь ставить Nautilus, принудительно указываем GTK для выбора файлов:
        "org.freedesktop.impl.portal.FileChooser" = "gtk"; 
      };
    };

    # Включаем systemd-юнит для gnome-keyring (Secret portal)
    services.gnome.gnome-keyring.enable = true;
    security.pam.services.gdm.enableGnomeKeyring = true; # если используешь GDM
}
