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
    inputs.niri.nixosModules.niri
  ];

  # ========================================
  # BOOT & KERNEL
  # ========================================
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  systemd.tmpfiles.rules = [ "d /etc/asusd 0755 root root -" ];
  services.asusd = {
    enable = true;
    fanCurvesConfig = null;
  };

  # ========================================
  # SYSTEM & LOCALE
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
  hardware.graphics.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  networking.networkmanager.enable = true;
  networking.firewall.enable = false;
  services.resolved.enable = true;
  services.netbird.enable = true;

  services.flatpak.enable = true;
  services.upower.enable = true;
  services.udisks2.enable = true;

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
    ];
    shell = pkgs.fish;
  };

  # Минимальные системные утилиты (всё остальное в Home Manager)
  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    asusctl
    gsettings-desktop-schemas
  ];

  environment.sessionVariables = {
    XDG_DATA_DIRS = [
      "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}"
    ];
  };

  # ========================================
  # DISPLAY & COMPOSITOR
  # ========================================
  programs.niri = {
    enable = true;
    package = pkgs.niri;
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
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  system.stateVersion = "26.05";
}
