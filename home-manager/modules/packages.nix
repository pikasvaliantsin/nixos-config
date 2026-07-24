{ config, pkgs, unstable, inputs, ... }:

{
  home.packages = with pkgs; [
    # Редакторы
    micro
    
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
    nh
    
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

    # === LSP серверы для NixVim ===
      nixd                    # Nix LSP (валидация, автодополнение)
      nil                     # Альтернативный Nix LSP (можно оба)
      nixfmt-rfc-style        # Форматировщик Nix-кода
      
      # Для других языков
      bash-language-server    # Bash LSP
      yaml-language-server    # YAML LSP
      taplo                   # TOML LSP
      lua-language-server     # Lua LSP
      
      # === Утилиты для разработки ===
      git
      ripgrep                 # Для Telescope live_grep
      fd                      # Для Telescope find_files
      gcc                     # Для компиляции некоторых плагинов
  ];
}
