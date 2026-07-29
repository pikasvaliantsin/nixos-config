{ config, pkgs, ... }:

{
  # Yazi
  xdg.configFile."yazi/yazi.toml" = {
    text = ''
      [opener]
      edit = [
        { run = 'micro "$@"', block = true }
      ]
      
      [manager]
      show_hidden = true
      sort_by = "natural"
    '';
    force = true;
  };

 #  programs.firefox = {
 #    enable = true;
 #    profiles.valen = { # замени "valen" на имя своего профиля
 #      settings = {
 #        # Явно задаем базовые шрифты, чтобы не использовались сломанные системные алиасы
 #        "font.name.sans-serif.x-western" = "Noto Sans";
 #        "font.name.serif.x-western" = "Noto Serif";
 #        "font.name.monospace.x-western" = "JetBrains Mono";
 #        
 #        # Запрещаем использовать сломанные системные UI-шрифты (message-box / system-ui)
 #        "layout.css.system-ui.enabled" = false;
 #        "layout.css.system-font-visibility.enabled" = false;
 #      };
 #    };
 #  };
 #  
 # programs.thunderbird = {
 #    enable = true;
 #    profiles.valen = {
 #      isDefault = true; # <-- Добавь эту строчку!
 #      
 #      settings = {
 #        "font.name.sans-serif.x-western" = "Noto Sans";
 #        "font.name.serif.x-western" = "Noto Serif";
 #        "font.name.monospace.x-western" = "JetBrains Mono";
 #        "layout.css.system-ui.enabled" = false;
 #      };
 #    };
 #  };

  # Декларативный конфиг dgop
  xdg.configFile."dgop/color.json".source = ./assets/dgop-color.json;
}
