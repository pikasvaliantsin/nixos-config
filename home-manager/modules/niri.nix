{
  config,
  pkgs,
  inputs,
  ...
}:

{
  # Импортируем модуль из sodiboo/niri-flake
  imports = [
    inputs.niri.homeModules.niri
  ];

  programs.niri = {
    enable = true;

    package = pkgs.niri;

    settings = {
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
      spawn-at-startup = [
        { command = [ "swww-daemon" ]; }
        { command = [ "waybar" ]; }
      ];

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
          position = { x = 0; y = 0; };
        };
        
        "eDP-1" = {
          mode = {
            width = 1920;
            height = 1080;
            refresh = 60.0;
          };
          scale = 1.0;
          position = { x = 3440; y = 0; };
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
        "Mod+Return" = { action.spawn = [ "alacritty" ]; };
        "Mod+T" = { action.spawn = [ "alacritty" ]; };
        "Mod+B" = { action.spawn = [ "firefox" ]; };
        "Super+Shift+B" = { action.spawn = [ "google-chrome" ]; };
        "Super+G" = { action.spawn = [ "steam" ]; repeat = false; };
        "Shift+Page_Up" = { action.spawn = [ "./scripts/toogle_key.sh" ]; repeat = false; };

        "Mod+D" = { action.spawn = [ "fuzzel" ]; };
        "Mod+V" = { action.spawn = [ "sh" "-c" "cliphist list | fuzzel --dmenu | cliphist decode | wl-copy" ]; };
        "Mod+Y" = { action.spawn = [ "sh" "-c" "ls ~/Pictures/Wallpapers | fuzzel --dmenu | xargs -I {} swww img ~/Pictures/Wallpapers/{}" ]; };
        "Mod+Alt+L" = { action.spawn = [ "swaylock" "-f" "--color" "1e1e2e" ]; };
        "Super+X" = { action.spawn = [ "wlogout" ]; };
        "Mod+M" = { action.spawn = [ "alacritty" "--title" "dgop" "-e" "dgop" ]; };
        "Ctrl+Alt+Delete" = { action.spawn = [ "alacritty" "--title" "dgop" "-e" "dgop" ]; };
        "Mod+N" = { action.spawn = [ "makoctl" "dismiss" "--all" ]; };

        "Mod+Shift+E" = { action.quit = {}; };
        "Mod+Escape" = { action.toggle-keyboard-shortcuts-inhibit = {}; allow-inhibiting = false; };
        "Mod+Shift+Slash" = { action.show-hotkey-overlay = {}; };
        "Mod+Tab" = { action.toggle-overview = {}; repeat = false; };
        "Mod+Shift+P" = { action.power-off-monitors = {}; };

        # ==========================================
        # УПРАВЛЕНИЕ ОКНАМИ И КОЛОНКАМИ
        # ==========================================
        "Mod+Q" = { action.close-window = {}; repeat = false; };
        "Mod+Shift+T" = { action.toggle-window-floating = {}; };
        "Mod+Shift+F" = { action.fullscreen-window = {}; };
        "Mod+F" = { action.maximize-column = {}; };
        "Mod+W" = { action.toggle-column-tabbed-display = {}; };
        "Mod+R" = { action.switch-preset-column-width = {}; };
        "Mod+Shift+R" = { action.switch-preset-window-height = {}; };
        "Mod+C" = { action.center-column = {}; };
        "Mod+Ctrl+C" = { action.center-visible-columns = {}; };
        "Mod+Ctrl+End" = { action.move-column-to-last = {}; };
        "Mod+Ctrl+Home" = { action.move-column-to-first = {}; };
        "Mod+Ctrl+F" = { action.expand-column-to-available-width = {}; };
        "Mod+Ctrl+R" = { action.reset-window-height = {}; };
        "Mod+Period" = { action.expel-window-from-column = {}; };
        "Mod+BracketLeft" = { action.consume-or-expel-window-left = {}; };
        "Mod+BracketRight" = { action.consume-or-expel-window-right = {}; };
        "Mod+Shift+V" = { action.switch-focus-between-floating-and-tiling = {}; };

        "Mod+Equal" = { action.set-column-width = "+10%"; };
        "Mod+Minus" = { action.set-column-width = "-10%"; };
        "Mod+Shift+Equal" = { action.set-window-height = "+10%"; };
        "Mod+Shift+Minus" = { action.set-window-height = "-10%"; };

        # ==========================================
        # ФОКУС
        # ==========================================
        # Колонки
        "Mod+Left" = { action.focus-column-left = {}; };
        "Mod+Right" = { action.focus-column-right = {}; };
        "Mod+H" = { action.focus-column-left = {}; };
        "Mod+L" = { action.focus-column-right = {}; };
        "Mod+Home" = { action.focus-column-first = {}; };
        "Mod+End" = { action.focus-column-last = {}; };

        # Окна
        "Mod+Up" = { action.focus-window-up = {}; };
        "Mod+Down" = { action.focus-window-down = {}; };
        "Mod+J" = { action.focus-window-down = {}; };
        "Mod+K" = { action.focus-window-up = {}; };

        # Мониторы (HJKL и стрелки)
        "Mod+Ctrl+H" = { action.focus-monitor-left = {}; };
        "Mod+Ctrl+J" = { action.focus-monitor-down = {}; };
        "Mod+Ctrl+K" = { action.focus-monitor-up = {}; };
        "Mod+Ctrl+L" = { action.focus-monitor-right = {}; };
        "Mod+Ctrl+Left" = { action.focus-monitor-left = {}; };
        "Mod+Ctrl+Right" = { action.focus-monitor-right = {}; };

        # ==========================================
        # ПЕРЕМЕЩЕНИЕ
        # ==========================================
        # Колонки
        "Mod+Shift+Left" = { action.move-column-left = {}; };
        "Mod+Shift+Right" = { action.move-column-right = {}; };
        "Mod+Shift+H" = { action.move-column-left = {}; };
        "Mod+Shift+L" = { action.move-column-right = {}; };

        # Окна
        "Mod+Shift+Up" = { action.move-window-up = {}; };
        "Mod+Shift+Down" = { action.move-window-down = {}; };
        "Mod+Shift+J" = { action.move-window-down = {}; };
        "Mod+Shift+K" = { action.move-window-up = {}; };

        # Колонки между мониторами
        "Mod+Shift+Ctrl+Left" = { action.move-column-to-monitor-left = {}; };
        "Mod+Shift+Ctrl+Right" = { action.move-column-to-monitor-right = {}; };
        "Mod+Shift+Ctrl+Up" = { action.move-column-to-monitor-up = {}; };
        "Mod+Shift+Ctrl+Down" = { action.move-column-to-monitor-down = {}; };
        "Mod+Shift+Ctrl+H" = { action.move-column-to-monitor-left = {}; };
        "Mod+Shift+Ctrl+J" = { action.move-column-to-monitor-down = {}; };
        "Mod+Shift+Ctrl+K" = { action.move-column-to-monitor-up = {}; };
        "Mod+Shift+Ctrl+L" = { action.move-column-to-monitor-right = {}; };

        # ==========================================
        # РАБОЧИЕ СТОЛЫ (WORKSPACES)
        # ==========================================
        # Переключение (цифры)
        "Mod+1" = { action.focus-workspace = 1; };
        "Mod+2" = { action.focus-workspace = 2; };
        "Mod+3" = { action.focus-workspace = 3; };
        "Mod+4" = { action.focus-workspace = 4; };
        "Mod+5" = { action.focus-workspace = 5; };
        "Mod+6" = { action.focus-workspace = 6; };
        "Mod+7" = { action.focus-workspace = 7; };
        "Mod+8" = { action.focus-workspace = 8; };
        "Mod+9" = { action.focus-workspace = 9; };

        # Переключение (стрелки и буквы)
        "Mod+I" = { action.focus-workspace-up = {}; };
        "Mod+U" = { action.focus-workspace-down = {}; };
        "Mod+Page_Up" = { action.focus-workspace-up = {}; };
        "Mod+Page_Down" = { action.focus-workspace-down = {}; };

        # Перемещение колонок на рабочие столы (цифры)
        "Mod+Shift+1" = { action.move-column-to-workspace = 1; };
        "Mod+Shift+2" = { action.move-column-to-workspace = 2; };
        "Mod+Shift+3" = { action.move-column-to-workspace = 3; };
        "Mod+Shift+4" = { action.move-column-to-workspace = 4; };
        "Mod+Shift+5" = { action.move-column-to-workspace = 5; };
        "Mod+Shift+6" = { action.move-column-to-workspace = 6; };
        "Mod+Shift+7" = { action.move-column-to-workspace = 7; };
        "Mod+Shift+8" = { action.move-column-to-workspace = 8; };
        "Mod+Shift+9" = { action.move-column-to-workspace = 9; };

        # Перемещение колонок на рабочие столы (стрелки и буквы)
        "Mod+Ctrl+Up" = { action.move-column-to-workspace-up = {}; };
        "Mod+Ctrl+Down" = { action.move-column-to-workspace-down = {}; };
        "Mod+Ctrl+I" = { action.move-column-to-workspace-up = {}; };
        "Mod+Ctrl+U" = { action.move-column-to-workspace-down = {}; };

        # Перемещение порядка рабочих столов
        "Mod+Shift+I" = { action.move-workspace-up = {}; };
        "Mod+Shift+U" = { action.move-workspace-down = {}; };
        "Mod+Shift+Page_Up" = { action.move-workspace-up = {}; };
        "Mod+Shift+Page_Down" = { action.move-workspace-down = {}; };

        # ==========================================
        # УПРАВЛЕНИЕ МЫШЬЮ (КОЛЕСО)
        # ==========================================
        "Mod+WheelScrollUp" = { action.focus-workspace-up = {}; cooldown-ms = 150; };
        "Mod+WheelScrollDown" = { action.focus-workspace-down = {}; cooldown-ms = 150; };
        "Mod+Shift+WheelScrollUp" = { action.focus-column-left = {}; };
        "Mod+Shift+WheelScrollDown" = { action.focus-column-right = {}; };
        "Mod+Ctrl+WheelScrollLeft" = { action.move-column-left = {}; };
        "Mod+Ctrl+WheelScrollRight" = { action.move-column-right = {}; };
        "Mod+Ctrl+WheelScrollUp" = { action.move-column-to-workspace-up = {}; cooldown-ms = 150; };
        "Mod+Ctrl+WheelScrollDown" = { action.move-column-to-workspace-down = {}; cooldown-ms = 150; };
        "Mod+Ctrl+Shift+WheelScrollUp" = { action.move-column-left = {}; };
        "Mod+Ctrl+Shift+WheelScrollDown" = { action.move-column-right = {}; };

        # ==========================================
        # УПРАВЛЕНИЕ ЗВУКОМ, ЯРКОСТЬЮ И СКРИНШОТАМИ
        # ==========================================
        "XF86AudioRaiseVolume" = { action.spawn = [ "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+" ]; allow-when-locked = true; };
        "XF86AudioLowerVolume" = { action.spawn = [ "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-" ]; allow-when-locked = true; };
        "XF86AudioMute" = { action.spawn = [ "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle" ]; allow-when-locked = true; };
        "XF86AudioMicMute" = { action.spawn = [ "wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle" ]; allow-when-locked = true; };
        "XF86MonBrightnessUp" = { action.spawn = [ "brightnessctl" "set" "5%+" ]; allow-when-locked = true; };
        "XF86MonBrightnessDown" = { action.spawn = [ "brightnessctl" "set" "5%-" ]; allow-when-locked = true; };

        "XF86AudioPlay" = { action.spawn = [ "playerctl" "play-pause" ]; allow-when-locked = true; };
        "XF86AudioPause" = { action.spawn = [ "playerctl" "play-pause" ]; allow-when-locked = true; };
        "XF86AudioNext" = { action.spawn = [ "playerctl" "next" ]; allow-when-locked = true; };
        "XF86AudioPrev" = { action.spawn = [ "playerctl" "previous" ]; allow-when-locked = true; };
        "Ctrl+XF86AudioRaiseVolume" = { action.spawn = [ "playerctl" "volume" "0.03+" ]; allow-when-locked = true; };
        "Ctrl+XF86AudioLowerVolume" = { action.spawn = [ "playerctl" "volume" "0.03-" ]; allow-when-locked = true; };

        "Print" = { action.screenshot = {}; };
        "Super+Shift+S" = { action.screenshot = {}; };
        "XF86Launch1" = { action.screenshot = {}; };
        "Ctrl+Print" = { action.screenshot-screen = {}; };
        "Ctrl+XF86Launch1" = { action.screenshot-screen = {}; };
        "Alt+Print" = { action.screenshot-window = {}; };
        "Alt+XF86Launch1" = { action.screenshot-window = {}; };
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
        # Плавающие окна для калькуляторов и диалогов
        
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
        gaps = 4;

        focus-ring = {
          width = 2;
          active = { color = "#bd93f9"; };
          inactive = { color = "#6272a4"; };
          urgent = { color = "#ff5555"; };
        };

        border = {
          width = 2;
          active = { color = "#bd93f9"; };
          inactive = { color = "#6272a4"; };
          urgent = { color = "#ff5555"; };
        };

        shadow = {
          color = "#00000070";
        };

        tab-indicator = {
          enable = true;
          active = { color = "#bd93f9"; };
          inactive = { color = "#6272a4"; };
          urgent = { color = "#ff5555"; };
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
  };
}
