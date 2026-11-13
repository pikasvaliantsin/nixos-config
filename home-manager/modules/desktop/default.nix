# Desktop-окружение: композитор, бары, порталы, темы, шрифты и монтирование.
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
    ./portals.nix
    ./udiskie.nix
    ./webapps.nix
    ./webapps-tui.nix
    ./quickshell.nix
    ./themes.nix
    inputs.dux-files.homeModules.dux-files
    inputs.dux-calendar.homeModules.dank-calendar
    inputs.dux-search.homeModules.dsearch
  ];

  programs.dux-files.enable = true;

  programs.dank-calendar = {
    enable = true;
    systemd.enable = true;
    settings = {
      use24HourClock = true;
      remindersEnabled = true;
    };
  };

  programs.dsearch.enable = true;

  # Конфиг niri: основной файл и бинды. theme.kdl линкуется в themes.nix.
  xdg.configFile = {
    "niri/config.kdl".source = mkLink "config.kdl";
    "niri/binds.kdl".source = mkLink "binds.kdl";
  };

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };
}
