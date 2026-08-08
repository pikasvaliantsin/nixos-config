# nixos-config/hosts/asus-expertbook/configuration.nix
{
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ./hardware.nix
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

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 100; # Увеличиваем до 100%
    priority = 10;
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
  };

  services.printing = {
    enable = true;
    drivers = [ pkgs.pantum-driver ];
  };

  hardware.sane = {
    enable = true;
    extraBackends = [ pkgs.sane-airscan ];
  };

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

  # Раскладка XKB для X11 / Xwayland / Gamescope
  services.xserver.xkb = {
    layout = "us,ru";
    options = "grp:win_space_toggle";
  };

  programs.xwayland.enable = true;

  # Включаем Steam системно
  programs.steam.enable = true;

  # 32-битная графика для Mesa (необходима для Steam и Proton)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Глобальные переменные окружения
  environment.sessionVariables = {
    XKB_DEFAULT_LAYOUT = "us,ru";
    XKB_DEFAULT_OPTIONS = "grp:win_space_toggle";
    XKB_CONFIG_ROOT = "${pkgs.xkeyboard_config}/share/X11/xkb";
    XDG_DATA_DIRS = [
      "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}"
    ];
  };

  # Системные пакеты
  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    gsettings-desktop-schemas
    xwayland-satellite
    xkeyboard_config
    libxkbcommon
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
  services.netbird.enable = true;

  services.flatpak.enable = true;
  services.upower.enable = true;
  services.udisks2.enable = true;

  services.gvfs.enable = true;

  # ========================================
  # USER & SHELL
  # ========================================
  programs.fish.enable = true;
  programs.dconf.enable = true;

  users.users.valen = {
    isNormalUser = true;
    initialPassword = "nixos";
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
  # DISPLAY & COMPOSITOR
  # ========================================
  programs.niri = {
    enable = true;
  };

  programs.dank-material-shell = {
    enable = true;
  };

  programs.dms-greeter = {
    enable = true;
    compositor.name = "niri";
    configHome = "/home/valen";
  };

  services.dbus.packages = with pkgs; [
    xdg-desktop-portal-gnome
  ];

  # ========================================
  # NIX SETTINGS
  # ========================================
  nixpkgs.config.allowUnfree = true;
  programs.appimage.enable = true;
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  system.stateVersion = "26.05";
}
