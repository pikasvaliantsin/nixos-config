{ config, pkgs, unstable, ... }:

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
    unstable.jetbrains-toolbox
    thunderbird
  ];
}
