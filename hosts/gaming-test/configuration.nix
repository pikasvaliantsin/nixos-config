# Тестовый хост: тот же текущий конфиг, но разметка — только RF4TEST-*
# (установка рядом с CachyOS). Основной хост asus-expertbook не меняется.
#
# Отличия от asus-expertbook/configuration.nix:
#   - ./disko.nix вместо полнодискового ../asus-expertbook/disko.nix;
#   - не импортируется sops.nix: для тестовой установки вход valen/rf4test;
#   - вместо desktop/niri.nix (DMS + dank-greeter + dux) — минимальный niri;
#   - вместо system/gaming.nix (Steam, Sunshine, input-remapper) — только
#     gamescope с CAP_SYS_NICE и gamemode;
#   - не импортируются printing, containers, fingerprint, rf4sim-guard,
#     nix-cache, omarchy-sudo;
#   - hostName = gaming-test.
{
  lib,
  ...
}:

{
  imports = [
    ./disko.nix
    ../asus-expertbook/hardware.nix

    ../asus-expertbook/system/boot.nix
    ../asus-expertbook/system/nvme-power.nix
    ../asus-expertbook/system/sleep-policy.nix
    ../asus-expertbook/system/locale.nix
    ../asus-expertbook/system/networking.nix
    ../asus-expertbook/system/services.nix
    ../asus-expertbook/system/graphics.nix
    ../asus-expertbook/system/nix.nix
    ../asus-expertbook/system/users.nix
    ../asus-expertbook/system/packages.nix

    ../asus-expertbook/desktop/custom-edid.nix

    ./desktop.nix
    ./gaming.nix
  ];

  networking.hostName = "gaming-test";

  hardware.customEdid.enable = true;

  system.stateVersion = "26.11";

  # Без sops на тестовой установке: пароль задаётся здесь.
  users.users.valen.hashedPasswordFile = lib.mkForce null;
  users.users.valen.initialPassword = "rf4test";
}
