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
    
    # Hyprland
    hyprpaper
    waybar
    wofi
    dunst
    hyprshot
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

    # Hyprpanel
    amdgpu_top
    bluez
    power-profiles-daemon
    hyprpicker
    btop
    matugen
    hyprpanel

    # Work
    jetbrains-toolbox
    thunderbird
  ];
}
