# Шрифты и иконки для терминала, GTK и Niri.
{ pkgs, ... }:

{
  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [
    inter
    roboto
    cantarell-fonts
    liberation_ttf
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    jetbrains-mono

    # Иконки для терминала/Yazi (Nerd Fonts)
    nerd-fonts.symbols-only

    # Иконки и темы GTK
    hicolor-icon-theme
    adwaita-icon-theme
    papirus-icon-theme
    font-awesome_6
    catppuccin-gtk
  ];
}
