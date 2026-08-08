# nixos-config/home-manager/modules/apps.nix
{
  pkgs,
  unstable,
  inputs,
  ...
}:

let
  toolbox = unstable.jetbrains-toolbox;
in
{
  # Список всех пользовательских пакетов
  home.packages = with pkgs; [
    # Файловые менеджеры и CLI утилиты
    alacritty
    yazi
    lsd
    tree
    bat
    jq
    unzip
    wget
    _7zip-zstd
    wl-clipboard
    cliphist
    fastfetch
    nh
    lazygit
    lazyssh
    xrandr
    simple-scan

    # GUI Приложения & Браузеры
    google-chrome
    thunderbird
    telegram-desktop
    yandex-music
    obs-studio
    obsidian
    vesktop
    toolbox
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    firefox

    imv # Для быстрых фоток по хоткеям
    loupe # Для удобного просмотра альбомов
    mpv # Для видео
    celluloid # GUI-оболочка для mpv

    # Внешние Flakes
    inputs.zoho-cliq.packages.${pkgs.stdenv.hostPlatform.system}.zoho-cliq

    # LSP серверы & Dev Tools
    nixd
    nixfmt
    bash-language-server
    yaml-language-server
    taplo
    lua-language-server
    ripgrep
    fd
    gcc
  ];

  # home-manager/default.nix
  services.udiskie = {
    enable = true;
    automount = true;
    notify = true;
  };

  # Конфигурация Yazi
  xdg.configFile."yazi/yazi.toml".text = ''
      [manager]
      show_hidden = true
      sort_by = "natural"

      [opener]
      edit = [ { run = 'nvim "$@"', block = true } ]
      open_image = [ { run = 'imv "$@"', orphan = true } ]
      open_video = [ { run = 'mpv "$@"', orphan = true } ]

      [open]
    rules = [
      { mime = "image/*", use = [ "open_image" ] },
      { mime = "video/*", use = [ "open_video" ] },
      { name = "*", mime = "*", use = [ "edit" ] }
    ]
  '';
  # Интеграция JetBrains URL Scheme
  xdg.dataFile."applications/jetbrainsd.desktop" = {
    text = ''
      [Desktop Entry]
      Version=1.5
      Name=JetBrains
      Type=Application
      NoDisplay=true
      MimeType=x-scheme-handler/jetbrains;
      Exec=${toolbox}/bin/jetbrains-toolbox %u
    '';
    force = true;
  };
  xdg.mimeApps.defaultApplications."x-scheme-handler/jetbrains" = "jetbrainsd.desktop";

  # Вспомогательный конфиг для dgop
  xdg.configFile."dgop/color.json".source = ./assets/dgop-color.json;
}
