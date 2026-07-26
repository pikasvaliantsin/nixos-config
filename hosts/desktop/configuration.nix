{
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ./hardware.nix
  ];

  # ========================================
  # BOOT & KERNEL
  # ========================================
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  systemd.tmpfiles.rules = [
    "d /etc/asusd 0755 root root -"
  ];

  services.asusd = {
    enable = true;
    fanCurvesConfig = null;
  };

  # ========================================
  # SYSTEM
  # ========================================
  networking.hostName = "asus-expertbook";
  time.timeZone = "Europe/Minsk";
  i18n.defaultLocale = "en_US.UTF-8";

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

  # ========================================
  # AUDIO
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

  # ========================================
  # USER
  # ========================================
  users.users.valen = {
    isNormalUser = true;
    initialPassword = "nixos"; # смени при первом входе
    extraGroups = [
      "wheel"
      "video"
      "audio"
      "input"
      "networkmanager"
    ];
    shell = pkgs.fish;
  };

  # ========================================
  # NETWORKING
  # ========================================
  networking.networkmanager.enable = true;

  # ========================================
  # BLUETOOTH
  # ========================================
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # ========================================
  # DNS
  # ========================================
  services.resolved.enable = true;

  # ========================================
  # NETBIRD VPN
  # ========================================
  services.netbird.enable = true;

  # Отключаем управление интерфейсом wt0 через NetworkManager,
  # чтобы NetBird мог сам управлять маршрутами.
  # networking.networkmanager.unmanaged = [ "wt0" ];

  # ========================================
  # FIREWALL
  # ========================================
  # Файрвол отключён, так как безопасность обеспечивается VPN.
  # Если хочешь включить — добавь правила для NetBird.
  networking.firewall.enable = false;

  # ========================================
  # SYSTEM PACKAGES
  # ========================================
  environment.systemPackages = with pkgs; [
    git
    micro
    fastfetch
    curl
    wget
    niri
    xwayland-satellite
    bibata-cursors
    asusctl
    greetd
    tuigreet
  ];

  # ========================================
  # NIX & MAINTENANCE
  # ========================================
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;

    extra-substituters = [
      "https://walker.cachix.org"
      "https://walker-git.cachix.org"
    ];
    extra-trusted-public-keys = [
      "walker.cachix.org-1:fG8q+uAaMqhsMxWjwvk0IMb4mFPFLqHjuvfwQxE4oJM="
      "walker-git.cachix.org-1:vmC0ocfPWh0S/vRAQGtChuiZBTAe4wiKDeyyXM0/7pM="
    ];
  };

  # Автоматическая очистка мусора (оставляем поколения за последние 14 дней)
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # Ограничиваем количество записей в systemd-boot, чтобы меню не раздувалось
  boot.loader.systemd-boot.configurationLimit = 10;

  nixpkgs.config.allowUnfree = true;
  # ========================================
  # SHELL
  # ========================================
  programs.fish.enable = true;

  services.flatpak.enable = true;

  services.upower.enable = true;
  services.udisks2.enable = true;

  # ========================================
  # WAYLAND, PORTALS & DESKTOP
  # ========================================
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk # Базовые диалоги (выбор файлов и т.д.)
      xdg-desktop-portal-gnome # Поддержка screencast (демонстрация экрана)
    ];
    configPackages = with pkgs; [
      niri
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
    ];
    config.common.default = "*";
  };

  # ==========================================
  # Включаем greetd
  # ==========================================
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd ${pkgs.niri}/bin/niri-session";
        user = "valen";
      };
    };
  };

  # Критически важно для GTK-приложений (включая PortProton/YAD) и Flatpak
  programs.dconf.enable = true;

  # ========================================
  # VERSION
  # ========================================
  system.stateVersion = "26.05";
}
