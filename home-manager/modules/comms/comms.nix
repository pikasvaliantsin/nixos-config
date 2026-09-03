# nixos-config/home-manager/modules/comms/comms.nix
{ pkgs, inputs, ... }:

{
  home.packages = [
    pkgs.vesktop
    inputs.ayugram-desktop.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
