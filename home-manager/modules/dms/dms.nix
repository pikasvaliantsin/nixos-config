# Живые конфиги DMS: out-of-store симлинки в git-репозиторий.
#
# DMS пишет состояние прямо в эти файлы, а не в Nix store, поэтому после
# переустановки достаточно развернуть nixos-config — настройки вернутся как были.
{
  config,
  pkgs,
  ...
}:

let
  configRoot = "${config.mySystem.dotfilesRoot}/home-manager/modules/dms";
  link = path: config.lib.file.mkOutOfStoreSymlink "${configRoot}/${path}";
in
{
  # Зависимости Wallhaven Carousel (цветовые фильтры и превью).
  home.packages = [
    pkgs.python3
    pkgs.imagemagick
  ];

  xdg.configFile = {
    # Фрагменты niri, которые DMS перегенерирует при каждом старте.
    # Симлинк на весь каталог, чтобы новые *.kdl тоже попадали в репо.
    "niri/dms".source = link "config";

    # Состояние самого DMS.
    "dms/settings.json".source = link "app/settings.json";
    "dms/plugin_settings.json".source = link "app/plugin_settings.json";
    "dms/plugins.lock.json".source = link "app/plugins.lock.json";
    "dms/monitors.json".source = link "app/monitors.json";
    "dms/clsettings.json".source = link "app/clsettings.json";
    "dms/themes".source = link "app/themes";
  };

  # Док-пины, порядок трея, настройки outputs и прочее состояние сессии.
  xdg.stateFile."dms/session.json".source = link "app/session.json";

  # plugin_settings.json не трекается в git: DMS хранит там API-ключи плагинов.
  # На новой машине создаём файл из обезличенного шаблона.
  home.activation.seedDmsPluginSettings = config.lib.dag.entryAfter [ "linkGeneration" ] ''
    target="${configRoot}/app/plugin_settings.json"
    if [ ! -e "$target" ]; then
      install -m 600 ${./app/plugin_settings.json.template} "$target"
    fi
  '';

  # Пункт в dock/лаунчере: открывает Wallhaven Carousel.
  # Пишем напрямую, потому что xdg.desktopEntries в текущей связке HM/nixpkgs
  # упирается в удалённый extraConfig.
  xdg.dataFile."applications/wallhavenCarousel.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Wallhaven
    GenericName=Wallpaper Browser
    Comment=Wallhaven wallpaper carousel
    Exec=dms ipc call wallhavenCarousel toggle
    Icon=preferences-desktop-wallpaper
    Terminal=false
    Categories=Graphics;Settings;
  '';
}
