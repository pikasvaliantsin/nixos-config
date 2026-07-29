{ pkgs, ... }:

{
  # Fontconfig & Шрифты
  fonts.fontconfig.enable = true;
  home.packages = with pkgs; [
    inter
    roboto
    cantarell-fonts
    liberation_ttf
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    jetbrains-mono

    # Иконки для терминала/Yazi (Nerd Fonts)
    nerd-fonts.symbols-only

    # Иконки и темы GTK
    hicolor-icon-theme
    adwaita-icon-theme
    papirus-icon-theme
    gnome-icon-theme
    font-awesome_6
    catppuccin-gtk
  ];

  # Niri Настройки
  programs.niri.settings = {
    # Пробрасываем Niri:GNOME в D-Bus сессию для работы Screencast портала
    spawn-at-startup = [
      { command = [ "dbus-update-activation-environment" "--systemd" "WAYLAND_DISPLAY" "XDG_CURRENT_DESKTOP=Niri:GNOME" "DISPLAY" ]; }
    ];

    environment = {
      WLR_NO_HARDWARE_CURSORS = "1";
      NIXOS_OZONE_WL = "1";
    };

    outputs = {
      "HDMI-A-1" = {
        mode = { width = 3440; height = 1440; refresh = 50.0; };
        scale = 1.0;
        position = { x = 0; y = 0; };
        focus-at-startup = true;
      };
      "eDP-1" = {
        mode = { width = 1920; height = 1080; refresh = 60.0; };
        scale = 1.0;
        position = { x = 3440; y = 0; };
      };
    };

    input = {
      keyboard.xkb = {
        layout = "us,ru";
        options = "grp:win_space_toggle,compose:ralt,ctrl:nocaps";
      };
      touchpad = {
        tap = true;
        natural-scroll = true;
      };
    };

    gestures.hot-corners.enable = false;

    binds = {
      "Mod+Return".action.spawn = [ "alacritty" ];
      "Mod+T".action.spawn = [ "alacritty" ];
      "Mod+B".action.spawn = [ "firefox" ];
      "Super+Shift+B".action.spawn = [ "google-chrome" ];
      "Super+G" = { action.spawn = [ "steam" ]; repeat = false; };
      "Shift+Page_Up" = { action.spawn = [ "./scripts/toogle_key.sh" ]; repeat = false; };
      "Super+Shift+S".action.screenshot = { };
    };

    window-rules = [
      {
        geometry-corner-radius = { top-left = 12.0; top-right = 12.0; bottom-left = 12.0; bottom-right = 12.0; };
        clip-to-geometry = true;
      }
      {
        matches = [
          { app-id = "^org.gnome.Calculator$"; }
          { app-id = "^org.keepassxc.KeePassXC$"; }
        ];
        open-floating = true;
      }
      # Правило оформления диалога выбора файлов
      {
        matches = [
          { app-id = "xdg-desktop-portal-gtk"; }
        ];
        default-column-width = { fixed = 900; };
        default-window-height = { fixed = 600; };
        geometry-corner-radius = {
          top-left = 12.0;
          top-right = 12.0;
          bottom-left = 12.0;
          bottom-right = 12.0;
        };
        open-on-output = "focused";
      }
    ];

    layout = {
      background-color = "transparent";
      gaps = 12;
      default-column-width.proportion = 0.5;
      focus-ring = {
        enable = true;
        width = 2;
        active.color = "#bd93f9";
        inactive.color = "#6272a4";
        urgent.color = "#ff5555";
      };
      border.enable = false;
      shadow.color = "#00000070";
      tab-indicator = {
        enable = true;
        active.color = "#bd93f9";
        inactive.color = "#6272a4";
        urgent.color = "#ff5555";
      };
      insert-hint = {
        enable = true;
        display.color = "#bd93f980";
      };
    };

    cursor.size = 24;
    screenshot-path = "~/Pictures/Screenshots/%Y-%m-%d_%H-%M-%S.png";
  };

  # XDG Portals & GTK / Dconf
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
    ];
    configPackages = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
      niri
    ];
    config = {
      common = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.Screencast" = [ "gnome" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "gnome" ];
      };
      niri = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
        "org.freedesktop.impl.portal.Screencast" = [ "gnome" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "gnome" ];
      };
    };
  };

  services.gnome-keyring.enable = true;

  # Настройки Dconf для File Chooser & Интерфейса
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      font-name = "Inter 10";
      text-scaling-factor = 1.0;
    };
    "org/gtk/settings/file-chooser" = {
      view-type = "grid";
      sort-column = "name";
      sort-order = "ascending";
      show-hidden = false;
      show-sidebar = true;
      icon-size = 48;
    };
  };

  # Темизация GTK
  gtk = {
    enable = true;
    font = {
      name = "Inter";
      size = 10;
    };
    theme = {
      name = "catppuccin-mocha-lavender-standard";
      package = pkgs.catppuccin-gtk.override {
        accents = [ "lavender" ];
        size = "standard";
        variant = "mocha";
      };
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
  };
}
