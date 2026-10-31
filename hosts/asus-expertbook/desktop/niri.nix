# Niri + DMS + greeter: всё, что относится к графической сессии хоста.
{
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    inputs.dms.nixosModules.dank-material-shell
    inputs.dank-greeter.nixosModules.default
  ];

  # ========================================
  # COMPOSITOR
  # ========================================
  programs = {
    niri = {
      enable = true;
      package = pkgs.niri;
    };

    dank-material-shell = {
      enable = true;
      # Запускаем шелл через systemd-юнит: тогда `dms restart` идёт через
      # `systemctl --user restart dms.service`, логи попадают в journal,
      # а не в /dev/null, и нет зомби-процессов после падения.
      systemd = {
        enable = true;
        # Не дёргать шелл при каждом nixos-rebuild switch.
        restartIfChanged = false;
      };
    };

    dms-greeter = {
      enable = true;
      compositor.name = "niri";
      configHome = "/home/valen";
    };

    # X11 / Xwayland
    xwayland.enable = true;

    # Нужен для gtk/gsettings пользовательских приложений
    dconf.enable = true;
  };

  systemd.services.greetd.restartIfChanged = false;

  # Небольшая пауза перед перезапуском упавшего шелла.
  systemd.user.services.dms.serviceConfig.RestartSec = "5s";

  services = {
    dbus.packages = with pkgs; [
      xdg-desktop-portal-gnome
    ];

    # Раскладка XKB для X11 / Xwayland / Gamescope
    xserver.xkb = {
      layout = "us,ru";
      options = "grp:win_space_toggle";
    };
  };

  # Глобальные переменные окружения для Wayland/XKB
  environment = {
    sessionVariables = {
      XKB_DEFAULT_LAYOUT = "us,ru";
      XKB_DEFAULT_OPTIONS = "grp:win_space_toggle";
      XKB_CONFIG_ROOT = "${pkgs.xkeyboard_config}/share/X11/xkb";
      XDG_DATA_DIRS = [
        "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}"
      ];

      # Нативный Wayland для Electron/Ozone и Firefox
      NIXOS_OZONE_WL = "1";
      MOZ_ENABLE_WAYLAND = "1";
    };

    # Системные пакеты, связанные с Wayland/X11
    systemPackages = with pkgs; [
      xwayland-satellite
      xkeyboard_config
      libxkbcommon
    ];
  };
}
