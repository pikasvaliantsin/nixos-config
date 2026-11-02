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

      # Greeter запускает niri с дефолтным конфигом без output-секций,
      # поэтому мониторы там раскладываются автоматически. Фиксируем ту же
      # раскладку, что и в сессии: HDMI-A-1 слева, eDP-1 справа.
      compositor.customConfig = ''
        hotkey-overlay {
            skip-at-startup
        }

        environment {
            DMS_RUN_GREETER "1"
        }

        input {
            keyboard {
                xkb {
                }
                numlock
            }

            touchpad {
                tap
                natural-scroll
            }

            mouse {
            }

            trackpoint {
            }
        }

        gestures {
            hot-corners {
                off
            }
        }

        layout {
            background-color "#000000"
        }

        output "HDMI-A-1" {
            mode "2240x960@119.898"
            scale 1
            position x=0 y=0
            variable-refresh-rate
        }

        output "eDP-1" {
            mode "1920x1080@60.164"
            scale 1
            position x=2240 y=0
        }
      '';
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

    # Раскладка XKB для X11 / Xwayland / Gamescope.
    # Сам Niri input (layout/options) настраивает DMS и пишет в dms/input.kdl.
    xserver.xkb = {
      layout = "us,ru";
      options = "grp:win_space_toggle,compose:ralt,ctrl:nocaps";
    };
  };

  # Глобальные переменные окружения для Xwayland/Electron/Gamescope.
  environment = {
    sessionVariables = {
      XKB_DEFAULT_LAYOUT = "us,ru";
      XKB_DEFAULT_OPTIONS = "grp:win_space_toggle,compose:ralt,ctrl:nocaps";
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
