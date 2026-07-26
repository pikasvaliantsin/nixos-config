{
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    inputs.walker.homeManagerModules.default
  ];

  # ==========================================
  # 1. Единая тема оформления (Catppuccin Mocha)
  # ==========================================
  gtk = {
    enable = true;
    theme = {
      name = "Catppuccin-Mocha";
      package = pkgs.catppuccin-gtk.override {
        accents = [ "mauve" ];
        size = "standard";
        tweaks = [
          "rimless"
          "black"
        ];
      };
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = "Bibata-Modern-Ice";
      package = pkgs.bibata-cursors;
      size = 24;
    };
    font = {
      name = "JetBrains Mono";
      size = 11;
    };
  };

  qt = {
    enable = true;
    platformTheme = "gtk";
    style.name = "adwaita-dark";
  };

  # ==========================================
  # 2. Фоновые сервисы (Services)
  # ==========================================
  services = {
    # mako = {
    #   enable = true;
    #   anchor = "top-right";
    #   width = 300;
    #   height = 150;
    #   margin = "10";
    #   defaultTimeout = 5000;
    #   extraConfig = ''
    #     border-size=2
    #     border-color=#cba6f7
    #     background-color=#1e1e2e
    #     text-color=#cdd6f4
    #   '';
    # };
    swaync = {
      enable = true;

      # Опционально: базовые настройки (позиция, стиль)
      settings = {
        position = "top-right";
        layer = "overlay";
        control-center-margin-top = 10;
        control-center-margin-bottom = 10;
        control-center-margin-right = 10;
        control-center-margin-left = 10;
        timeout = 5;
        timeout-low = 5;
        timeout-critical = 0;
      };
    };

    cliphist = {
      enable = true;
      systemdTargets = [ "graphical-session.target" ];
      allowImages = true;
    };
  }; # <-- ВАЖНО: эта скобка закрывает блок services

  # ==========================================
  # 3. Программы с конфигами (Programs)
  # ==========================================
  programs = {
    walker = {
      enable = true;
      runAsService = true;
    };

    waybar = {
      enable = true;
      systemd.enable = true;

      settings = {
        mainBar = {
          layer = "top";
          position = "top";
          height = 36;
          margin-top = 8;
          margin-left = 8;
          margin-right = 8;
          margin-bottom = 0;

          # === РАСКЛАДКА ===
          modules-left = [
            "niri/workspaces"
          ];

          modules-center = [
            "clock"
            "custom/weather" # <-- Погода
          ];

          modules-right = [
            "custom/notification" # <-- Уведомления
            "pulseaudio"
            "network"
            "battery"
            "tray" # <-- Tray ВСЕГДА должен быть последним!
          ];

          # === МОДУЛИ ===

          "niri/workspaces" = {
            format = "{icon}";
            format-icons = {
              "active" = "●";
              "default" = "○";
            };
            on-click = "activate";
            on-scroll-up = "niri msg action focus-workspace-up";
            on-scroll-down = "niri msg action focus-workspace-down";
            all-outputs = false;
          };

          "clock" = {
            format = "{:%H:%M    %d.%m}";
            tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
          };

          # === ПОГОДА (добавлен недостающий блок!) ===
          "custom/weather" = {
            format = "{}";
            tooltip = true;
            interval = 1800; # Обновление каждые 30 минут
            exec = "curl -s 'wttr.in/?format=%C+%t&lang=ru'";
            on-click = "xdg-open 'https://wttr.in/'"; # Клик — открыть в браузере
          };

          # === УВЕДОМЛЕНИЯ (скобки закрыты!) ===
          "custom/notification" = {
            tooltip = false;
            format = "{icon}";
            format-icons = {
              notification = "<span foreground='red'><sup></sup></span>";
              none = "";
              dnd-notification = "<span foreground='red'><sup></sup></span>";
              dnd-none = "";
              inhibited-notification = "<span foreground='red'><sup></sup></span>";
              inhibited-none = "";
              dnd-inhibited-notification = "<span foreground='red'><sup></sup></span>";
              dnd-inhibited-none = "";
            };
            return-type = "json";
            exec-if = "which swaync-client";
            exec = "swaync-client -swb";
            on-click = "swaync-client -t -sw";
            on-click-right = "swaync-client -d -sw";
            escape = true;
          };

          "pulseaudio" = {
            format = "{icon} {volume}%";
            format-icons = {
              default = [
                ""
                ""
                ""
              ];
            };
            on-click = "pavucontrol";
          };

          "network" = {
            format-wifi = "  {essid}";
            format-ethernet = "  {ifname}";
            format-disconnected = "  Отключено";
            tooltip-format = "  {essid} | {ipaddr}";
          };

          "battery" = {
            states = {
              warning = 20;
              critical = 10;
            };
            format = "{icon} {capacity}%";
            format-icons = [
              ""
              ""
              ""
              ""
              ""
            ];
          };

          "tray" = {
            icon-size = 16;
            spacing = 8;
          };
        };
      };

      style = ''
        * {
          font-family: "JetBrainsMono Nerd Font", sans-serif;
          font-size: 13px;
        }

        window#waybar {
          background-color: rgba(40, 42, 54, 0.85);
          border-radius: 12px;
          color: #f8f8f2;
        }

        #workspaces button {
          padding: 0 8px;
          color: #6272a4;
        }

        #workspaces button.active {
          color: #bd93f9;
        }

        #custom-weather {
          padding: 0 12px;
          color: #8be9fd;
        }

        #custom-notification {
          padding: 0 12px;
          color: #f8f8f2;
        }

        #clock, #pulseaudio, #network, #battery {
          padding: 0 12px;
          margin: 0 4px;
        }
      '';
    };
  }; # <-- ВАЖНО: эта скобка закрывает блок programs

  # ==========================================
  # 4. Пакеты и пользовательские systemd-сервисы
  # ==========================================
  home.packages = with pkgs; [
    wl-clipboard
    cliphist
    swww
    pavucontrol
    brightnessctl
  ];

  systemd.user.services.swww = {
    Unit.Description = "Simple Wayland Wallpaper Daemon";
    Service = {
      ExecStart = "${pkgs.swww}/bin/swww-daemon";
      Restart = "always";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
