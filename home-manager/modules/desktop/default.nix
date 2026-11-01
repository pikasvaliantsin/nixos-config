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

  programs.dux-files.enable = true;

  # Подключаем основной config.kdl через symlink
  xdg.configFile."niri/config.kdl".source = mkLink "config.kdl";
  xdg.configFile."niri/hm.kdl".source = mkLink "hm.kdl";

  # XDG user dirs: без ~/.config/user-dirs.dirs DMS не находит ~/Pictures
  # и складывает скриншоты (dms screenshot) прямо в $HOME.
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };
}
