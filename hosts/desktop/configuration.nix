{ config, pkgs, inputs, ... }:

{
  imports = [
    ./hardware.nix
  ];

  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # System
  networking.hostName = "asus-expertbook";
  time.timeZone = "Europe/Moscow";
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

  programs.hyprland.enable = true;

  # Audio
  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
  };
  security.rtkit.enable = true;

  # Users
  users.users.valen = {
    isNormalUser = true;
    initialPassword = "nixos";
    extraGroups = [ "wheel" "video" "audio" "input" "networkmanager" ];
    shell = pkgs.fish;
  };

  # Networking
  networking.networkmanager.enable = true;

  # System packages
  environment.systemPackages = with pkgs; [
    git
    micro
    fastfetch
    htop
    curl
    wget
  ];

  # Nix settings
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };

  nixpkgs.config.allowUnfree = true;

  # Включаем поддержку fish
  programs.fish.enable = true;

  system.stateVersion = "26.05";

}
