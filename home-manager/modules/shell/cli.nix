# nixos-config/home-manager/modules/shell/cli.nix
{ pkgs, inputs, ... }:

{
  # CLI-утилиты
  home.packages = with pkgs; [
    # Файловые менеджеры
    yazi

    # CLI-улучшения
    lsd
    tree
    bat
    jq
    ripgrep
    fd
    _7zip-zstd

    # Сетевые утилиты
    wget
    curl

    # Архивация
    unzip

    # Секреты и шифрование
    sops
    age
    ssh-to-age

    # Wayland-утилиты
    libinput
    wl-clipboard
    cliphist

    # TUI-утилиты
    nh
    lazygit
    lazyssh
    opencode
    inputs.pyroclear.packages.${pkgs.stdenv.hostPlatform.system}.default
    # Отдельный CLI dgop из nixpkgs (в dms 2.0 он встроен в бэкенд как
    # библиотека, поэтому nix-модуль dms его больше не ставит)
    pkgs."dux-gop"

    # X11-утилиты
    xrandr

    # Сканер (зависит от hardware.sane)
    simple-scan
  ];

  # Конфигурация Yazi
  xdg.configFile."yazi/yazi.toml".text = ''
    [manager]
    show_hidden = true
    sort_by = "natural"

    [opener]
    edit = [
      { run = 'nvim "%s"', block = true, for = "unix" }
    ]
    open_image = [
      { run = 'imv "%s"', orphan = true, for = "unix" }
    ]
    open_video = [
      { run = 'mpv "%s"', orphan = true, for = "unix" }
    ]

    [open]
    rules = [
      { mime = "image/*", use = [ "open_image" ] },
      { mime = "video/*", use = [ "open_video" ] },
      { name = "*", mime = "*", use = [ "edit" ] }
    ]
  '';

  # Вспомогательный конфиг для dgop
  xdg.configFile."dgop/color.json".source = ../assets/dgop-color.json;
}
