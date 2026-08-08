# home-manager/modules/dms/dms.nix
{
  config,
  pkgs,
  inputs,
  ...
}:

let
  dmsPath = "${config.home.homeDirectory}/nixos-config/home-manager/modules/dms/config";
  mkLink = file: config.lib.file.mkOutOfStoreSymlink "${dmsPath}/${file}";
in
{
  imports = [
    inputs.dms.homeModules.dank-material-shell
  ];

  programs.dank-material-shell = {
    enable = true;
    dgop.package = inputs.dgop.packages.${pkgs.stdenv.hostPlatform.system}.default;
  };
  systemd.user.services.dms.Service = {
    Restart = "always";
    RestartSec = "1s";
  };
  xdg.configFile = {
    "niri/dms/alttab.kdl".source = mkLink "alttab.kdl";
    "niri/dms/binds.kdl".source = mkLink "binds.kdl";
    "niri/dms/colors.kdl".source = mkLink "colors.kdl";
    "niri/dms/cursor.kdl".source = mkLink "cursor.kdl";
    "niri/dms/layout.kdl".source = mkLink "layout.kdl";
    "niri/dms/outputs.kdl".source = mkLink "outputs.kdl";
    "niri/dms/windowrules.kdl".source = mkLink "windowrules.kdl";
    "niri/dms/wpblur.kdl".source = mkLink "wpblur.kdl";
  };
}
