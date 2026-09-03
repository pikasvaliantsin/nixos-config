# home-manager/modules/dms/dms.nix
{ config, pkgs, lib, inputs, ... }:

let
  cfg = config.mySystem.dms;
  dmsConfig = ./config;
in
{
  options.mySystem.dms.enable = lib.mkEnableOption "Dank Material Shell and extensions" // {
    default = false;
  };

  imports = [
    inputs.dms.homeModules.dank-material-shell
  ];

  config = {
    # Конфиги ДМС доступны всегда (для импортов в niri/config.kdl),
    # даже если сам DMS отключён как служба или пакет.
    xdg.configFile."niri/dms" = {
      source = dmsConfig;
      recursive = true;
    };

    # Остальное работает только при включённом DMS
  } // lib.mkIf cfg.enable {
    programs.dank-material-shell = {
      enable = true;
      # dgop.package обновлён в новой версии DMS (используй программы.plugins)
      # dgop.package = inputs.dgop.packages.${pkgs.stdenv.hostPlatform.system}.default;
    };

    systemd.user.services.dms.restartIfChanged = false;
    systemd.user.services.dms.RestartSec = "5s";
  };
}
