# nixos-config/home-manager/modules/comms/comms.nix
{ pkgs, inputs, ... }:

{
  home.packages = [
    pkgs.vesktop
    inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.ayugram-ffmpeg6
  ];
}
