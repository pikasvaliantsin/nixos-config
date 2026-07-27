{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:

let
  dmsPath = "/home/valen/nixos-config/home-manager/modules/dms/config";
  mkLink = file: config.lib.file.mkOutOfStoreSymlink "${dmsPath}/${file}";
in

{
  imports = [
    inputs.dms.homeModules.dank-material-shell
    inputs.dms.homeModules.niri
  ];

  programs.dank-material-shell = {
    enable = true;

    niri = {
      includes = {
        enable = true;
        override = true;
        originalFileName = "hm";
        filesToInclude = [
                "alttab"
                "binds"
                "colors"
                "cursor"
                "layout"
                "outputs"
                "windowrules"
                "wpblur"
              ];
      };
      enableSpawn = true;
      enableKeybinds = false;
    };

    dgop.package = inputs.dgop.packages.${pkgs.stdenv.hostPlatform.system}.default;
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
