{ pkgs, ... }:

{
  # Обязательно для регистраций шрифтов в пользователе через Home Manager
  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [
    # --- ШРИФТЫ ДЛЯ UI И СИСТЕМЫ ---
    inter                 # Основной Material/UI шрифт (нужен для DMS и Firefox)
    roboto                # Резервный UI шрифт
    cantarell-fonts       # Стандартный шрифт GTK/GNOME (убирает невидимый текст в Mozilla)
    liberation_ttf        # Метрические аналог Arial/Times
    noto-fonts            # Базовые шрифты Noto
    noto-fonts-cjk-sans   # Символы и азиатские глифы
    noto-fonts-color-emoji      # Цветные Emoji
    jetbrains-mono # Терминальный моноширинный шрифт с иконками

    # --- ИКОНКИ ---
    hicolor-icon-theme    # Базовый набор (обязателен для большинства GTK приложений)
    adwaita-icon-theme    # Стандартные иконки GNOME/Wayland
    papirus-icon-theme    # Современный пак иконок Papirus
    gnome-icon-theme      # Дополнительные иконки GNOME
    font-awesome_6        # Шрифтовые иконки (FontAwesome v6)
  ];
}
