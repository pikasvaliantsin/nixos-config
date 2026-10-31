{
  config,
  lib,
  ...
}:

let
  cfg = config.hardware.customEdid;
in
{
  options.hardware.customEdid = {
    enable = lib.mkEnableOption "Кастомный режим 21:9 @ 120Hz";

    output = lib.mkOption {
      type = lib.types.str;
      default = "HDMI-A-1";
      description = "Имя видеовыхода";
    };

    mode = lib.mkOption {
      type = lib.types.str;
      default = "2240x960";
      description = "Разрешение 21:9";
    };

    refresh = lib.mkOption {
      type = lib.types.str;
      default = "120";
      description = "Частота обновления";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelParams = [
      "drm.modeset=1"
      # Посылаем ядру сигнал сформировать CVT Reduced Blanking (R) для 2240x960 @ 120Hz
      "video=${cfg.output}:${cfg.mode}MR-32@${cfg.refresh}"
    ];
  };
}
