# Живые конфиги DMS: out-of-store симлинки в git-репозиторий.
#
# DMS пишет состояние прямо в эти файлы, а не в Nix store, поэтому после
# переустановки достаточно развернуть nixos-config — настройки вернутся как были.
{ config, ... }:

let
  configRoot = "${config.mySystem.dotfilesRoot}/home-manager/modules/dms";
  link = path: config.lib.file.mkOutOfStoreSymlink "${configRoot}/${path}";
in
{
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
}
