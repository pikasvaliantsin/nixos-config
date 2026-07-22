{ config, pkgs, ... }:

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
    ripgrep
    fd
    bat
    jq
    unzip
    wget
    
    # Браузеры
    firefox
    google-chrome

    # Шрифты
    jetbrains-mono
    inter-nerdfont
    font-awesome
    material-design-icons
    nerd-fonts.symbols-only

    # Work
    jetbrains-toolbox
    thunderbird
  ];
}
