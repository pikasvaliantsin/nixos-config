# Точка входа хоста: только identity, stateVersion и подключение модулей.
_:

{
  imports = [
    ./hardware.nix
    ./disko.nix
    ./sops.nix

    ./system/boot.nix
    ./system/locale.nix
    ./system/networking.nix
    ./system/printing.nix
    ./system/services.nix
    ./system/fingerprint.nix
    ./system/graphics.nix
    ./system/gaming.nix
    ./system/nix.nix
    ./system/users.nix
    ./system/packages.nix

    ./desktop/niri.nix
    ./desktop/custom-edid.nix
  ];

  networking.hostName = "asus-expertbook";

  # Кастомный режим внешнего монитора 21:9 @ 120Hz
  hardware.customEdid.enable = true;

  system.stateVersion = "26.11";
}
