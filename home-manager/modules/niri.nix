{
  config,
  pkgs,
  inputs,
  ...
}:

{
  # Импортируем модуль из sodiboo/niri-flake
  # imports = [
  #   inputs.niri.homeModules.niri
  # ];

  programs.niri.settings = {
      # ==========================================
      # 1. Переменные окружения
      # ==========================================
      environment = {
        WLR_NO_HARDWARE_CURSORS = "1";
        NIXOS_OZONE_WL = "1";
      };

      # ==========================================
      # 2. Автозапуск программ
      # ==========================================
      # spawn-at-startup = [
      #   { command = [ "swww-daemon" ]; }
      # ];

      # ==========================================
      # Оверлей горячих клавиш
      # ==========================================
      #skip-at-startup = true;

      # ==========================================
      # Мониторы (Outputs)
      # ==========================================
      outputs = {
        "HDMI-A-1" = {
          mode = {
            width = 3440;
            height = 1440;
            refresh = 50.0;
          };
          scale = 1.0;
          position = {
            x = 0;
            y = 0;
          };
          focus-at-startup = true;
        };

        "eDP-1" = {
          mode = {
            width = 1920;
            height = 1080;
            refresh = 60.0;
          };
          scale = 1.0;
          position = {
            x = 3440;
            y = 0;
          };
        };
      };

      # ==========================================
      # Ввод (Клавиатура)
      # ==========================================
      input = {
        keyboard = {
          xkb = {
            layout = "us,ru";
            options = "grp:win_space_toggle,compose:ralt,ctrl:nocaps";
          };
        };
        touchpad = {
          tap = true;
          natural-scroll = true;
        };
      };

      # ==========================================
      # Жесты и горячие углы
      # ==========================================
      gestures = {
        hot-corners = {
          enable = false;
        };
      };

      # ==========================================
      # 3. Горячие клавиши
      # ==========================================
      binds = {
        # ==========================================
        # СИСТЕМНЫЕ И ПРИЛОЖЕНИЯ
        # ==========================================
        "Mod+Return" = {
          action.spawn = [ "alacritty" ];
        };
        "Mod+T" = {
          action.spawn = [ "alacritty" ];
        };
        "Mod+B" = {
          action.spawn = [ "firefox" ];
        };
        "Super+Shift+B" = {
          action.spawn = [ "google-chrome" ];
        };
        "Super+G" = {
          action.spawn = [ "steam" ];
          repeat = false;
        };
        "Shift+Page_Up" = {
          action.spawn = [ "./scripts/toogle_key.sh" ];
          repeat = false;
        };

        "Super+Shift+S" = {
          action.screenshot = { };
        };
      };
      # ==========================================
      # 4. Правила для окон
      # ==========================================
      window-rules = [
        # Скругленные углы для всех окон
        {
          geometry-corner-radius = {
            top-left = 12.0;
            top-right = 12.0;
            bottom-left = 12.0;
            bottom-right = 12.0;
          };
          clip-to-geometry = true;
        }

        # Плавающие окна для калькуляторов и диалогов
        {
          matches = [
            { app-id = "^org.gnome.Calculator$"; }
            { app-id = "^org.keepassxc.KeePassXC$"; }
          ];
          open-floating = true;
        }

      ];

      # ==========================================
      # Визуальное оформление (Dracula Palette)
      # ==========================================
      layout = {
        background-color = "transparent";
        gaps = 12;
        default-column-width = {
          proportion = 0.5;
        };

        focus-ring = {
          enable = true;
          width = 2;
          active = {
            color = "#bd93f9";
          };
          inactive = {
            color = "#6272a4";
          };
          urgent = {
            color = "#ff5555";
          };
        };

        border = {
          enable = false;
          width = 2;
          active = {
            color = "#bd93f9";
          };
          inactive = {
            color = "#6272a4";
          };
          urgent = {
            color = "#ff5555";
          };
        };

        shadow = {
          color = "#00000070";
        };

        tab-indicator = {
          enable = true;
          active = {
            color = "#bd93f9";
          };
          inactive = {
            color = "#6272a4";
          };
          urgent = {
            color = "#ff5555";
          };
        };

        insert-hint = {
          enable = true;
          display = {
            color = "#bd93f980";
          };
        };
      };

      # ==========================================
      # Недавние окна (Recent Windows)
      # ==========================================
      #recent-windows = {
      #highlight = {
      #  corner-radius = 12.0;
      #  active-color = "#7c5ac7";
      #  urgent-color = "#ff5555";
      #};
      #};
      # ==========================================
      # 5. Прочие настройки
      # ==========================================
      cursor = {
        size = 24;
      };

      screenshot-path = "~/Pictures/Screenshots/%Y-%m-%d_%H-%M-%S.png";

      # Анимации
      #animations = {
      #slowdown = 1.0;
      #window-open = "slide-left";
      #window-close = "slide-right";
      #};
    };
}
