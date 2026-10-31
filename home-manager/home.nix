# nixos-config/home-manager/home.nix
{ inputs, ... }:

{
  imports = [
    inputs.nix-flatpak.homeManagerModules.nix-flatpak
    inputs.nixvim.homeModules.nixvim
    ./modules/core.nix
    ./modules/core/secrets.nix
    ./modules/shell.nix
    ./modules/editors/editors.nix
    ./modules/editors/dev.nix
    ./modules/browsers/browsers.nix
    ./modules/comms/comms.nix
    ./modules/media/media.nix
    ./modules/productivity/productivity.nix
    ./modules/desktop.nix
    ./modules/games/games.nix
    ./modules/games/rf4.nix
  ];
}
