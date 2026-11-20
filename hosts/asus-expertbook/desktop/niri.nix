# Niri + DMS + greeter: всё, что относится к графической сессии хоста.
{
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [
    inputs.dank-greeter.nixosModules.default
  ];

  # Build niri main against this system's nixpkgs (glibc/Mesa), not the
  # niri flake's older pin. The flake's own package used glibc 2.42 while
  # /run/opengl-driver already needed 2.43, which left the greeter black.
  nixpkgs.overlays = [ inputs.niri-git.overlays.default ];

  # ========================================
  # COMPOSITOR
  # ========================================
  programs = {
    niri = {
      enable = true;
      package = pkgs.niri;
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
                    layout "us,ru"
                    options "grp:win_space_toggle,compose:menu,ctrl:nocaps"
                }
                numlock
                track-layout "window"
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
            mode "1920x1080@120.000"
            scale 1
            position x=0 y=0
            variable-refresh-rate
        }

        output "eDP-1" {
            mode "1920x1080@60.164"
            scale 1
            position x=1920 y=0
        }
      '';
    };

    # X11 / Xwayland
    xwayland.enable = true;

    # Нужен для gtk/gsettings пользовательских приложений
    dconf.enable = true;
  };

  systemd.services.greetd.restartIfChanged = false;

  # dux-greeter preStart копирует DMS session.json в /var/lib/dms-greeter и
  # переписывает wallpaperPath на /var/lib/dms-greeter/wallpaper. Если в
  # session.json уже лежит этот переписанный путь (например, после переезда
  # с Omarchy), upstream делает `cp` файла самого в себя. Из-за `set -e`
  # greetd падает ещё до запуска композитора:
  #   cp: '/var/lib/dms-greeter/wallpaper' and 'wallpaper' are the same file
  #
  # Подменяем cp на обёртку, которая молча пропускает self-copy. Так сохраняется
  # и upstream-логика, и обои, а greetd не падает.
  systemd.services.greetd.preStart = lib.mkBefore ''
    cp() {
      if [ "$#" -eq 2 ]; then
        if [ "$1" -ef "$2" ]; then
          return 0
        fi
        if [ -d "$2" ] && [ "$1" -ef "$2/$(basename "$1")" ]; then
          return 0
        fi
      fi
      command cp "$@"
    }
  '';

  # PAM для gtklock: обычный логин + отпечаток.
  security.pam.services.gtklock = {
    fprintAuth = true;
    enableGnomeKeyring = true;
  };

  services = {
    dbus.packages = with pkgs; [
      xdg-desktop-portal-gnome
    ];

    # Раскладка XKB для X11 / Xwayland / Gamescope.
    # Niri input (layout/options) задан в modules/niri/config.kdl.
    xserver.xkb = {
      layout = "us,ru";
      options = "grp:win_space_toggle,compose:menu,ctrl:nocaps";
    };
  };

  # Глобальные переменные окружения для Xwayland/Electron/Gamescope.
  environment = {
    sessionVariables = {
      XKB_DEFAULT_LAYOUT = "us,ru";
      XKB_DEFAULT_OPTIONS = "grp:win_space_toggle,compose:menu,ctrl:nocaps";
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
