# home-manager/modules/dms/dms.nix
{ config, pkgs, lib, inputs, ... }:

let
  cfg = config.mySystem.dms;

  # Всё состояние DMS (и фрагменты niri, которые он генерирует) держим в git-репозитории.
  # Это не стор-копии, а out-of-store симлинки: DMS пишет прямо в файлы репо,
  # поэтому после переустановки конфиг восстанавливается из nixos-config как есть.
  configRoot = "${cfg.dotfilesRoot}/home-manager/modules/dms";
  link = path: config.lib.file.mkOutOfStoreSymlink "${configRoot}/${path}";
in
{
  options.mySystem.dms.enable = lib.mkEnableOption "Dank Material Shell and extensions" // {
    default = false;
  };

  imports = [
    inputs.dms.homeModules.dank-material-shell
  ];

  config = lib.mkMerge [
    # Конфиги доступны всегда (для импортов в niri/config.kdl), даже если сам DMS
    # отключён как пакет/служба.
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

    (lib.mkIf cfg.enable {
      # Пакет и systemd-юнит включает NixOS-модуль (programs.dank-material-shell),
      # здесь — только home-manager-часть.
      programs.dank-material-shell = {
        enable = true;
      };

      systemd.user.services.dms.restartIfChanged = false;
      systemd.user.services.dms.RestartSec = "5s";
    })
  ];
}
