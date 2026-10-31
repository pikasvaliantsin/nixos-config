# GTK-тема и настройки dconf.
{ pkgs, ... }:

{
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      font-name = "Inter 10";
      text-scaling-factor = 1.0;
    };
    "org/gtk/settings/file-chooser" = {
      view-type = "grid";
      sort-column = "name";
      sort-order = "ascending";
      show-hidden = false;
      show-sidebar = true;
      icon-size = 48;
    };
  };

  gtk = {
    enable = true;
    font = {
      name = "Inter";
      size = 10;
    };
    theme = {
      name = "catppuccin-mocha-lavender-standard";
      package = pkgs.catppuccin-gtk.override {
        accents = [ "lavender" ];
        size = "standard";
        variant = "mocha";
      };
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
  };
}
