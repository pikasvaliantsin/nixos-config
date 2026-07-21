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
    kitty
    
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

    # Hyprpanel
    amdgpu_top
    bluez
    bluez-utils
    power-profiles-daemon
    hyprpicker
    btop
    matugen
    hyprpanel
  ];
}
