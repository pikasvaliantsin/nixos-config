{ config, pkgs, inputs, ... }:

{
  services.flatpak = {
    enable = true;

    remotes = [
      {
        name = "flathub";
        location = "https://flathub.org/repo/flathub.flatpakrepo";
      }
    ];

    packages = [
      "ru.linux_gaming.PortProton"
    ];

    update.onActivation = true;

    overrides.settings = {
      "ru.linux_gaming.PortProton" = {
        Context = {
          sockets = [ "wayland" "fallback-x11" ];
          devices = [ "dri" ];
          share = [ "ipc" ]; 
        };
        Environment = {
          # Оставляем: это чинит логику отрисовки попапов в GTK/YAD
          XDG_CURRENT_DESKTOP = "GNOME";
          
          # Добавляем: заставляет UI рендериться через CPU, убирая мерцание, 
          # но НЕ ломает бэкенд запуска игры (в отличие от GDK_BACKEND=x11)
          GSK_RENDERER = "cairo";
          
          # ВАЖНО: явно удаляем GDK_BACKEND из окружения, если он там вдруг остался
          GDK_BACKEND = ""; 
        };
      };
    };
  };
}
