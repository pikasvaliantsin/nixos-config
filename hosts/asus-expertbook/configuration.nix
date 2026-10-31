# nixos-config/hosts/asus-expertbook/configuration.nix
{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:

{
  imports = [
    ./hardware.nix
    ./niri.nix
    ./sops.nix
    inputs.dms.nixosModules.dank-material-shell
    inputs.dank-greeter.nixosModules.default
  ];

  # ========================================
  # BOOT & KERNEL
  # ========================================
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Адаптивное управление частотой CPU (performance от сети, powersave от батареи)
  services.auto-cpufreq = {
    enable = true;
    settings = {
      charger = {
        governor = "performance";
        turbo = "auto";
      };
      battery = {
        governor = "powersave";
        turbo = "never";
      };
    };
  };

  # Отключаем power-profiles-daemon — конфликтует с auto-cpufreq
  services.power-profiles-daemon.enable = false;

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 80; # Оставляем 20% RAM для GPU и фоновых задач
    priority = 100; # Приоритет выше disk swap
  };

  boot.kernel.sysctl = {
    # Агрессивный сброс страниц в zRAM
    "vm.swappiness" = 180;

    # КРИТИЧНО ДЛЯ zRAM: отключает чтение страниц блоками (кластерами).
    # Для дисков нужна упреждающая вычитка, для RAM latency равна 0 — читаем строго по 4 КБ.
    "vm.page-cluster" = 0;

    # Борьба со статтерами и пиками задержек (актуально для игр и тяжелых билдов)
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 125;

    # Proton/Wine: требуется для Unity/Unreal игр (без этого краши на старте)
    "vm.max_map_count" = 2147483642;
  };

  services.printing = {
    enable = true;
    drivers = [ pkgs.pantum-driver ];
  };

  hardware.sane = {
    enable = true;
    extraBackends = [ pkgs.sane-airscan ];
  };

  boot.kernelParams = [
    "amd_pstate=active"
    "iommu=pt"
    "video=HDMI-A-1:2240x960MR-32@120"
  ];

  # Служба для проброса IPP/eSCL через USB
  services.ipp-usb.enable = true;

  # Автообнаружение сетевых устройств/принтеров (DNS-SD / mDNS)
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # ========================================
  # SYSTEM & LOCALE
  # ========================================
  networking.hostName = "asus-expertbook";
  time.timeZone = "Europe/Minsk";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "ru_RU.UTF-8/UTF-8"
  ];

  i18n.extraLocaleSettings = {
    LC_TIME = "ru_RU.UTF-8";
    LC_MONETARY = "ru_RU.UTF-8";
    LC_ADDRESS = "ru_RU.UTF-8";
    LC_TELEPHONE = "ru_RU.UTF-8";
    LC_MEASUREMENT = "ru_RU.UTF-8";
    LC_IDENTIFICATION = "ru_RU.UTF-8";
  };

  console = {
    font = "cyr-sun16";
    keyMap = "us";
  };

  programs.kdeconnect = {
    enable = true;
    package = pkgs.kdePackages.kdeconnect-kde;
  };

  # ========================================
  # GRAPHICS & GAMING
  # ========================================
  # 32-битная графика для Mesa + аппаратное декодирование VA-API
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      libva
      libva-utils
      # Vulkan loader: без него /run/opengl-driver/lib/libvulkan.so.1
      # отсутствует, и Wine/DXVK не могут получить VK_KHR_surface.
      vulkan-loader
      vulkan-tools
      # libEGL.so.1 / libGL.so.1 (диспетчер GLVND) — нужны Wine для wgl/egl.
      libglvnd
    ];
    extraPackages32 = [
      # 32-битные loader и GLVND нужны лончеру RF4.exe и wine (WINE_LG).
      pkgs.pkgsi686Linux.vulkan-loader
      pkgs.pkgsi686Linux.libglvnd
    ];
  };

  # Wine — не nix-пакет, /etc/ld.so.cache на NixOS нет, поэтому libvulkan.so.1
  # и libEGL.so.1 он может найти только через LD_LIBRARY_PATH.
  environment.sessionVariables.LD_LIBRARY_PATH = [
    "/run/opengl-driver/lib"
    "/run/opengl-driver-32/lib"
  ];

  # 32-битный ELF-загрузчик в стандартном месте /lib/ld-linux.so.2.
  # Нужен Wine (wineboot, explorer, cmd) и 32-битному RF4Launcher.exe:
  # без него любой 32-битный процесс Wine падает с "could not open".
  environment.ldso32 = "${pkgs.pkgsi686Linux.glibc}/lib/ld-linux.so.2";

  # Системный Steam и расширение FHS-рантайма
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
    package = pkgs.steam.override {
      extraPkgs = pkgs: with pkgs; [
        vulkan-loader
        vulkan-tools
        fontconfig
        freetype
        libxkbcommon
        gnutls
        openssl
        nss
        nspr
        dbus
        zlib
      ];
    };
  };

  # GameMode: авто-оптимизация при запуске игр (приоритет, governor, CPU boost)
  # + Gamescope: изоляция игровых процессов от Wayland-компа
  programs.gamemode.enable = true;
  programs.gamemode.settings = {
    general = {
      renice = 10; # Приоритет процесса игры
    };
    gpu = {
      gpu_device = 0; # Указываем GPU для Vega 7
    };
  };
  programs.gamescope.enable = true;

  # Системные пакеты
  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    gsettings-desktop-schemas
    btrfs-progs
  ];

  # ========================================
  # SERVICES & HARDWARE
  # ========================================
  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
  };
  security.rtkit.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  networking.networkmanager.enable = true;

  # Настройка файрвола с поддержкой NetBird
  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "wt0" ];
    checkReversePath = "loose";
    allowedUDPPorts = [ 51820 ];
  };

  services.resolved.enable = true;

  services.flatpak.enable = true;
  services.upower.enable = true;
  services.udisks2.enable = true;

  services.gvfs.enable = true;

  # Обслуживание SSD (TRIM)
  services.fstrim.enable = true;

  # ========================================
  # USER & SHELL
  # ========================================
  programs.fish.enable = true;
  programs.dconf.enable = true;

  users.users.valen = {
    isNormalUser = true;
    hashedPasswordFile = "/run/secrets/valen_password";
    extraGroups = [
      "wheel"
      "video"
      "audio"
      "input"
      "render"
      "networkmanager"
      "lp"
      "scanner"
    ];
    shell = pkgs.fish;
  };

  # ========================================
  # NIX SETTINGS & OVERLAYS
  # ========================================
  nixpkgs.config.allowUnfree = true;
  programs.appimage.enable = true;
  programs.nix-ld.enable = true;

  nixpkgs.overlays = [
    # Оверлей для согласования steam-run с рантаймом Steam
    (final: prev: {
      steam-run = (prev.steam.override {
        extraPkgs = pkgs: with pkgs; [
          vulkan-loader
          vulkan-tools
          fontconfig
          freetype
          libxkbcommon
          gnutls
          openssl
          nss
          nspr
          dbus
          zlib
        ];
      }).run;
    })

    # Пользовательские патчи и совместимость
    (final: prev: {
      minizip-ng-compat = prev.minizip-ng;
      khal = prev.khal.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          mkdir -p $man/share/man/man1
          touch $man/share/man/man1/khal.1
        '';
      });
    })
  ];

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = false;
    max-jobs = "auto";
    trusted-users = [
      "root"
      "@wheel"
    ];
    substituters = [
      "https://cache.nixos.org"
      "https://ayugram-desktop.cachix.org"
      "https://tg-owt.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "ayugram-desktop.cachix.org-1:AZ5EqHrJsAKL5YkZYLPEsb1FdD9QlypUwQ0REcJftgA="
      "tg-owt.cachix.org-1:lp0BukIhSK3EIyLcDhDZ5zABgT48nmNp6t4SnZ0wr8w="
    ];
  };

  nix.gc = {
    automatic = false;
    dates = "";
  };

  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;

  system.stateVersion = "26.11";
}