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
    micro
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
    nautilus

    # GUI Приложения & Браузеры
    firefox
    google-chrome
    thunderbird
    telegram-desktop
    yandex-music
    obs-studio
    obsidian
    vesktop
    unstable.jetbrains-toolbox

    # Игры
    steam
    gamescope
    bottles


    # Внешние Flakes
    inputs.zoho-cliq.packages.${pkgs.stdenv.hostPlatform.system}.zoho-cliq

    # LSP серверы & Dev Tools
    nixd
    nil
    nixfmt-rfc-style
    bash-language-server
    yaml-language-server
    taplo
    lua-language-server
    ripgrep
    fd
    gcc
  ];

  # Конфигурация Yazi
  xdg.configFile."yazi/yazi.toml".text = ''
    [opener]
    edit = [ { run = 'micro "$@"', block = true } ]
    [manager]
    show_hidden = true
    sort_by = "natural"
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

  # Flatpak декларация
  services.flatpak = {
    enable = true;
    remotes = [
      {
        name = "flathub";
        location = "https://flathub.org/repo/flathub.flatpakrepo";
      }
    ];
    packages = [ "ru.linux_gaming.PortProton" ];
    update.onActivation = true;

    overrides.settings."ru.linux_gaming.PortProton" = {
      Context = {
        sockets = [
          "wayland"
          "fallback-x11"
        ];
        devices = [ "dri" ];
        share = [ "ipc" ];
      };
      Environment = {
        XDG_CURRENT_DESKTOP = "GNOME";
        GSK_RENDERER = "cairo";
        GDK_BACKEND = "";
      };
    };
  };

  # Вспомогательный конфиг для dgop
  xdg.configFile."dgop/color.json".source = ./assets/dgop-color.json;
}
