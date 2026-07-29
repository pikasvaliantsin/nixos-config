{ config, pkgs, ... }:

{
  xdg.portal = {
    enable = true;

    # 1. Оставляем ТОЛЬКО порталы (gnome-keyring отсюда убираем, это не xdg-portal бэкенд)
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
    ];

    # 2. Пакеты, конфиги которых учитываются
    configPackages = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
      niri
    ];

    # 3. Правильная структура порталов для Niri (исправлены типы данных на списки [ ])
    config = {
      common = {
        default = [ "gtk" ];
      };
      niri = {
        default = [ "gnome" "gtk" ];
        # Принудительно используем GTK для выбора файлов (если Nautilus не установлен)
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
        # Захват экрана и скриншоты строго отдаем GNOME-порталу
        "org.freedesktop.impl.portal.Screencast" = [ "gnome" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "gnome" ];
      };
    };
  };

  # 4. Включаем gnome-keyring правильно для Home Manager (без вложенности .gnome)
  services.gnome-keyring.enable = true;

  # 5. ЛЕЧИМ ШРИФТЫ В FIREFOX / THUNDERBIRD (-0.13888px) И ТЕМНУЮ ТЕМУ
  # Задаем dconf-параметры, которые читает xdg-desktop-portal-gnome
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      font-name = "Inter 10";
      text-scaling-factor = 1.0;
    };
  };

  gtk = {
    enable = true;
    font = {
      name = "Inter";
      size = 10;
    };
  };
}
