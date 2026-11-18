# nixos-config/home-manager/home.nix
{ inputs, ... }:

{
  imports = [
    inputs.nixvim.homeModules.nixvim
    inputs.superwhisper.homeManagerModules.default
    ./modules/core.nix
    ./modules/core/secrets.nix
    ./modules/shell.nix
    ./modules/editors/editors.nix
    ./modules/editors/dev.nix
    ./modules/editors/openide.nix
    ./modules/browsers/browsers.nix
    ./modules/comms/comms.nix
    ./modules/media/media.nix
    ./modules/productivity/productivity.nix
    ./modules/desktop
    ./modules/games/games.nix
    ./modules/games/rf4.nix
    ./modules/games/fs25.nix
  ];

  # Superwhisper dictation (Omarchy's default backend). The module installs
  # the package, desktop entry and systemd user service.
  services.superwhisper.enable = true;
}
