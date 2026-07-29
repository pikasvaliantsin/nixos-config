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
    inputs.niri.nixosModules.niri

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

  hardware.graphics = {
    enable = true;
    #enable3dbindings = true;
  };

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
      "render"
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
    xwayland-satellite
    bibata-cursors
    asusctl
    gsettings-desktop-schemas
    dconf
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

  programs.dconf.enable = true;

  environment.sessionVariables = {
    XDG_DATA_DIRS = [
      "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}"
    ];
  };

  # Включаем системный Niri
  programs.niri = {
    enable = true;
    package = pkgs.niri;
  };

  # Настраиваем Dank Greeter на уровне системы
  programs.dms-greeter = {
    enable = true;
    compositor.name = "niri";
    configHome = "/home/valen";
  };
  # ========================================
  # VERSION
  # ========================================
  system.stateVersion = "26.05";
}
