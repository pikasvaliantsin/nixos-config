# nixos-config/home-manager/home.nix
{ inputs, ... }:

{
  imports = [
    inputs.nix-flatpak.homeManagerModules.nix-flatpak
    inputs.nixvim.homeModules.nixvim
    ./modules/core.nix
    ./modules/shell.nix
    ./modules/apps.nix
    ./modules/desktop.nix
    ./modules/editors.nix
    ./modules/dms/dms.nix
  ];
}
