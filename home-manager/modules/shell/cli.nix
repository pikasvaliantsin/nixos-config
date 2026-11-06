# nixos-config/home-manager/modules/shell/cli.nix
{ pkgs, inputs, ... }:

let
  # Обход поломки nixpkgs (2026-11-03): у opencode 2.2.5 устарел хеш
  # node_modules, FOD падает с hash mismatch. Собираем FOD с фактическим
  # хешем. Убрать, когда nixpkgs починят (хеш в package.nix обновят).
  opencodeNodeModules = pkgs.stdenv.mkDerivation {
    pname = "opencode-node_modules";
    inherit (pkgs.opencode) version src;

    __structuredAttrs = true;
    strictDeps = true;

    impureEnvVars = pkgs.lib.fetchers.proxyImpureEnvVars ++ [
      "GIT_PROXY_COMMAND"
      "SOCKS_SERVER"
    ];

    nativeBuildInputs = [ pkgs.bun pkgs.writableTmpDirAsHomeHook ];

    dontConfigure = true;

    buildPhase = ''
      runHook preBuild

      export BUN_INSTALL_CACHE_DIR=$(mktemp -d)
      bun install \
        --cpu="*" \
        --filter './' \
        --filter './packages/cli' \
        --filter './packages/desktop' \
        --filter './packages/app' \
        --frozen-lockfile \
        --ignore-scripts \
        --no-progress \
        --os="*"

      bun --bun ./nix/scripts/canonicalize-node-modules.ts
      bun --bun ./nix/scripts/normalize-bun-binaries.ts

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out
      find . -type d -name node_modules -exec cp -R --parents {} $out \;
      find $out -type f -name '*.exe' -delete

      runHook postInstall
    '';

    dontFixup = true;
    outputHash = "sha256-prx9dX7kUvs/E3zopkaPk5LXh3xJAy5sZeum/W8L7cA=";
    outputHashMode = "recursive";
  };

  opencode = pkgs.opencode.overrideAttrs (_: {
    node_modules = opencodeNodeModules;
  });
in
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

    # Архивация
    unzip

    # Секреты и шифрование
    sops
    age
    ssh-to-age

    # Wayland-утилиты
    libinput
    wl-clipboard

    # TUI-утилиты
    nh
    lazygit
    lazyssh
    opencode
    inputs.pyroclear.packages.${pkgs.stdenv.hostPlatform.system}.default
    # Отдельный CLI dgop из nixpkgs (в dms 2.0 он встроен в бэкенд как
    # библиотека, поэтому nix-модуль dms его больше не ставит)
    pkgs."dux-gop"

    # Мониторинг (sensors: k10temp + amdgpu; нужно для замеров до/после
    # замены термопасты)
    lm_sensors

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
