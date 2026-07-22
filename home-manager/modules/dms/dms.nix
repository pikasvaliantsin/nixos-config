{ config, pkgs, inputs, ... }:

let
  dmsPkg = inputs.dms.packages.${pkgs.system}.dms-shell;
in
{
  systemd.user.services.dms = {
    Unit = {
      Description = "Dank Material Shell";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${dmsPkg}/bin/dms run";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
