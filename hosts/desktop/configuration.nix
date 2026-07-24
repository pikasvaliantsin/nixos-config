{ config, pkgs, inputs, ... }:

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
    LC_TIME           = "ru_RU.UTF-8";
    LC_MONETARY       = "ru_RU.UTF-8";
    LC_ADDRESS        = "ru_RU.UTF-8";
    LC_TELEPHONE      = "ru_RU.UTF-8";
    LC_MEASUREMENT    = "ru_RU.UTF-8";
    LC_IDENTIFICATION = "ru_RU.UTF-8";
  };

  console = {
    font    = "cyr-sun16";
    keyMap  = "us";
  };

  # ========================================
  # NIRI (Wayland compositor)
  # ========================================
  programs.niri.enable = true;
  programs.dank-material-shell = {
    enable = true;
    enableSystemMonitoring = true;
    dgop.package = inputs.dgop.packages.${pkgs.system}.default;
  };
  programs.dms-greeter = {
    enable = true;
    compositor.name = "niri"; # or hyprland, sway, labwc, mango, scroll, miracle
    configHome = "/home/valen"; # copies that user's DMS settings (and wallpaper) into the greeter data directory before greetd starts
  };

  # ========================================
  # AUDIO
  # ========================================
  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa = {
      enable         = true;
      support32Bit   = true;
    };
  };
  security.rtkit.enable = true;

  # ========================================
  # USER
  # ========================================
  users.users.valen = {
    isNormalUser    = true;
    initialPassword = "nixos";   # смени при первом входе
    extraGroups     = [
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
    enable        = true;
    powerOnBoot   = true;
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
    htop
    curl
    wget
    xwayland-satellite
    asusctl
  ];

  # ========================================
  # NIX
  # ========================================
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store   = true;
  };

   nixpkgs.config.allowUnfree = true;

  # ========================================
  # SHELL
  # ========================================
  programs.fish.enable = true;

  services.flatpak.enable = true;
  xdg.portal.enable = true;

  services.upower.enable = true;
  services.udisks2.enable = true;

  # ========================================
  # VERSION
  # ========================================
  system.stateVersion = "26.05";
}
