{
  pkgs,
  config,
  lib,
  inputs,
  ...
}:

let
  configPath = "${config.home.homeDirectory}/nixos-config/home-manager/modules/niri";
  mkLink = file: config.lib.file.mkOutOfStoreSymlink "${configPath}/${file}";
in
{
  imports = [
    ./dms/dms.nix
    inputs.dux-files.homeModules.dux-files
  ];

  # DMS отключён по умолчанию (включить через mySystem.dms.enable)
  mySystem.dms.enable = false;
  programs.dux-files.enable = true;

  # Подключаем основной config.kdl через symlink
  xdg.configFile."niri/config.kdl".source = mkLink "config.kdl";
  xdg.configFile."niri/hm.kdl".source = mkLink "hm.kdl";

  # Автоматическое монтирование съёмных носителей
  services.udiskie = {
    enable = true;
    automount = true;
    notify = true;
  };

  # Fontconfig & Шрифты
  fonts.fontconfig.enable = true;
  home.packages = with pkgs; [
    inter
    roboto
    cantarell-fonts
    liberation_ttf
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    jetbrains-mono

    # Иконки для терминала/Yazi (Nerd Fonts)
    nerd-fonts.symbols-only

    # Иконки и темы GTK
    hicolor-icon-theme
    adwaita-icon-theme
    papirus-icon-theme
    font-awesome_6
    catppuccin-gtk
  ];

  # Niri Настройки

  # XDG Portals & GTK / Dconf
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
    ];
    configPackages = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
      niri
    ];
    config = {
      common = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.Screencast" = [ "gnome" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "gnome" ];
      };
      niri = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
        "org.freedesktop.impl.portal.Screencast" = [ "gnome" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "gnome" ];
      };
    };
  };

  services.gnome-keyring.enable = true;

  # Настройки Dconf для File Chooser & Интерфейса
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      font-name = "Inter 10";
      text-scaling-factor = 1.0;
    };
    "org/gtk/settings/file-chooser" = {
      view-type = "grid";
      sort-column = "name";
      sort-order = "ascending";
      show-hidden = false;
      show-sidebar = true;
      icon-size = 48;
    };
  };

  # Темизация GTK
  gtk = {
    enable = true;
    font = {
      name = "Inter";
      size = 10;
    };
    theme = {
      name = "catppuccin-mocha-lavender-standard";
      package = pkgs.catppuccin-gtk.override {
        accents = [ "lavender" ];
        size = "standard";
        variant = "mocha";
      };
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
  };
}
