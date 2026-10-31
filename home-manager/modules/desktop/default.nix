# Desktop-окружение: композитор, порталы, темы, шрифты и монтирование.
{
  config,
  inputs,
  ...
}:

let
  configPath = "${config.mySystem.dotfilesRoot}/home-manager/modules/niri";
  mkLink = file: config.lib.file.mkOutOfStoreSymlink "${configPath}/${file}";
in
{
  imports = [
    ./fonts.nix
    ./gtk.nix
    ./keyring.nix
    ./portals.nix
    ./udiskie.nix
    ../dms/dms.nix
    inputs.dux-files.homeModules.dux-files
  ];

  # DMS отключён на уровне home-manager (системный модуль включается в
  # hosts/asus-expertbook/desktop/niri.nix). Включать через mySystem.dms.enable.
  mySystem.dms.enable = false;
  programs.dux-files.enable = true;

  # Подключаем основной config.kdl через symlink
  xdg.configFile."niri/config.kdl".source = mkLink "config.kdl";
  xdg.configFile."niri/hm.kdl".source = mkLink "hm.kdl";
}
