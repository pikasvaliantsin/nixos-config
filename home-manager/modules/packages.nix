{ config, pkgs, unstable, inputs, ... }:

{
  home.packages = with pkgs; [
    # Редакторы
    micro
    vim
    
    # Файловые менеджеры
    yazi
    lsd
    
    # Терминал
    alacritty
    
    # Утилиты
    tree
    fd
    bat
    jq
    unzip
    wget
    cups-pk-helper
    upower
    _7zip-zstd
    gtk3
    desktop-file-utils
    wl-clipboard
    
    # Браузеры
    firefox
    google-chrome

    # Шрифты
    jetbrains-mono
    inter-nerdfont
    font-awesome
    material-design-icons
    nerd-fonts.symbols-only

    # Иконки
    hicolor-icon-theme       # базовый набор
    adwaita-icon-theme       # стандартные иконки GNOME
    papirus-icon-theme       # современный набор (рекомендую)
    gnome-icon-theme         # дополнительные иконки GNOME

    # Soft
    unstable.jetbrains-toolbox
    thunderbird
    steam
    gamescope
    telegram-desktop
    yandex-music
    obs-studio
    obsidian
    inputs.zoho-cliq.packages.${pkgs.system}.zoho-cliq
    bottles
    vesktop
  ];
}
