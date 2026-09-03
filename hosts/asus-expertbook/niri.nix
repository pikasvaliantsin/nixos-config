# nixos-config/hosts/asus-expertbook/niri.nix
{
  pkgs,
  config,
  inputs,
  ...
}:

{
  # ========================================
  # DISPLAY & COMPOSITOR
  # ========================================
  programs.niri = {
    enable = true;
    package = pkgs.niri;
  };

  programs.dank-material-shell = {
    enable = true;
  };

  programs.dms-greeter = {
    enable = true;
    compositor.name = "niri";
    configHome = "/home/valen";
  };
  systemd.services.greetd.restartIfChanged = false;

  services.dbus.packages = with pkgs; [
    xdg-desktop-portal-gnome
  ];

  # X11 / Xwayland
  programs.xwayland.enable = true;

  # Раскладка XKB для X11 / Xwayland / Gamescope
  services.xserver.xkb = {
    layout = "us,ru";
    options = "grp:win_space_toggle";
  };

  # Глобальные переменные окружения для Wayland/XKB
  environment.sessionVariables = {
    XKB_DEFAULT_LAYOUT = "us,ru";
    XKB_DEFAULT_OPTIONS = "grp:win_space_toggle";
    XKB_CONFIG_ROOT = "${pkgs.xkeyboard_config}/share/X11/xkb";
    XDG_DATA_DIRS = [
      "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}"
    ];

    # Нативный Wayland для Electron/Ozone и Firefox
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };

  # Системные пакеты, связанные с Wayland/X11
  environment.systemPackages = with pkgs; [
    xwayland-satellite
    xkeyboard_config
    libxkbcommon
  ];
}
