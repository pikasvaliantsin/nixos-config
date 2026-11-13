# TUI `webapps` для mySystem.webapps.
#
# Не генерирует Nix-код: правит JSON рядом с модулем (webapps.json), который
# webapps.nix читает как список записей. Ошибка в TUI не может сломать
# конфигурацию — максимум испортит один JSON, а тот проверяется jq.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.mySystem.webapps.tui;

  # Файл, который читает webapps.nix (./webapps.json рядом с модулем).
  # В обычном checkout это тот же путь: dotfilesRoot/home-manager/modules/desktop.
  jsonFile = "${config.mySystem.dotfilesRoot}/home-manager/modules/desktop/webapps.json";

  rebuildArgs = if cfg.rebuildCommand == null then "" else lib.escapeShellArgs cfg.rebuildCommand;

  script =
    lib.replaceStrings
      [ "@JSON_FILE@" "@DOTFILES@" "@REBUILD@" ]
      [ jsonFile config.mySystem.dotfilesRoot rebuildArgs ]
      (builtins.readFile ./webapps-tui.sh);

  webappsTui = pkgs.writeShellApplication {
    name = cfg.command;
    runtimeInputs = with pkgs; [
      gum
      jq
      curl
      coreutils
      util-linux
      git
    ];
    # jq-скрипты используют $name/$key в одинарных кавычках — это не shell.
    excludeShellChecks = [ "SC2016" ];
    text = script;
  };
in
{
  options.mySystem.webapps.tui = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Установить TUI `webapps` для добавления/удаления записей.";
    };

    command = lib.mkOption {
      type = lib.types.str;
      default = "webapps";
      description = "Имя команды.";
    };

    rebuildCommand = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = [
        "nh"
        "os"
        "switch"
      ];
      description = ''
        Команда применения изменений, запускается в корне dotfiles.
        null — не предлагать пересборку из TUI.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ webappsTui ];
  };
}
