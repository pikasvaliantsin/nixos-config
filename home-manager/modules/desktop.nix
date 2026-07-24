{ config, pkgs, ... }:

{
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
    mako = {
      enable = true;
      anchor = "top-right";
      width = 300;
      height = 150;
      margin = "10";
      defaultTimeout = 5000;
      extraConfig = ''
        border-size=2
        border-color=#cba6f7
        background-color=#1e1e2e
        text-color=#cdd6f4
      '';
    };
  }; # <-- ВАЖНО: эта скобка закрывает блок services

  # ==========================================
  # 3. Программы с конфигами (Programs)
  # ==========================================
  programs = {
    fuzzel = {
      enable = true;
      settings = {
        main = {
          font = "JetBrains Mono:size=12";
          terminal = "${pkgs.alacritty}/bin/alacritty";
          lines = 15;
          width = 45;
        };
        colors = {
          background = "1e1e2eff";
          text = "cdd6f4ff";
          match = "f38ba8ff";
          selection = "313244ff";
          selection-match = "f38ba8ff";
          selection-text = "cdd6f4ff";
          border = "cba6f7ff";
        };
      };
    };

    waybar = {
      enable = true;
      systemd.enable = true;
      settings = {
        mainBar = {
          layer = "top";
          position = "top";
          modules-left = [
            "niri/workspaces"
            "niri/window"
          ];
          modules-center = [ "clock" ];
          modules-right = [
            "pulseaudio"
            "network"
            "battery"
            "tray"
          ];

          "niri/workspaces" = {
            all-outputs = true;
            format = "{icon}";
            format-icons = {
              "1" = "1";
              "2" = "2";
              "3" = "3";
              "active" = "";
              "default" = "";
            };
          };
          "clock" = {
            format = "{:%H:%M    %d.%m}";
            tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
          };
        };
      };
      style = ''
        * { font-family: "JetBrains Mono"; font-size: 12px; }
        window#waybar { background-color: rgba(30, 30, 46, 0.9); color: #cdd6f4; }
        #workspaces button { padding: 0 10px; color: #cba6f7; }
        #workspaces button.active { color: #f38ba8; }
        #clock, #pulseaudio, #network, #battery { padding: 0 15px; }
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

  # Декларативный конфиг dgop
  xdg.configFile."dgop/color.json".source = ./assets/dgop-color.json;
}
