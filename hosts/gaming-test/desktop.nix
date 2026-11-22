# Минимальная графическая сессия для теста RF4: niri без DMS/Omarchy/dux.
# Нужна только для запуска `rf4-gs` из терминала.
{ pkgs, ... }:

{
  programs.niri.enable = true;
  programs.xwayland.enable = true;
  programs.dconf.enable = true;

  # Лёгкий логин вместо dank-greeter: TTY-login + запуск niri.
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd ${pkgs.niri}/bin/niri-session";
      user = "greeter";
    };
  };

  services.xserver.xkb = {
    layout = "us,ru";
    options = "grp:win_space_toggle,compose:menu,ctrl:nocaps";
  };

  environment = {
    sessionVariables = {
      XKB_DEFAULT_LAYOUT = "us,ru";
      XKB_DEFAULT_OPTIONS = "grp:win_space_toggle,compose:menu,ctrl:nocaps";
      XKB_CONFIG_ROOT = "${pkgs.xkeyboard_config}/share/X11/xkb";
      NIXOS_OZONE_WL = "1";
      MOZ_ENABLE_WAYLAND = "1";
    };

    systemPackages = with pkgs; [
      xwayland-satellite
      xkeyboard_config
      libxkbcommon
    ];
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };
}
