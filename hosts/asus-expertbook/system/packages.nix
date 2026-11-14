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

  # Системные шрифты нужны greeter'у (он работает под пользователем greeter
  # и не видит home-manager-профиль valen), а также TTY/root-сессиям.
  # DejaVu/Liberation/Noto покрывают кириллицу.
  fonts = {
    fontconfig.enable = true;
    packages = with pkgs; [
      dejavu_fonts
      liberation_ttf
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
    ];
  };
}
