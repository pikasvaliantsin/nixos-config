# XDG-порталы: скринкасты и file chooser под Niri.
{ pkgs, inputs, ... }:

{
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
    ];
    configPackages = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
      inputs.niri-git.packages.${pkgs.stdenv.hostPlatform.system}.niri
    ];
    config = {
      common = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.Screencast" = [ "gnome" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "gnome" ];
      };
      niri = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
        "org.freedesktop.impl.portal.Screencast" = [ "gnome" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "gnome" ];
      };
    };
  };
}
