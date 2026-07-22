{ config, pkgs, inputs, unstable, ... }:

{
  imports = [
    ./modules/core.nix
    ./modules/shell.nix
    ./modules/git.nix
    ./modules/terminal.nix
    ./modules/programs.nix
    ./modules/packages.nix
    ./modules/editors.nix
    ./modules/jetbrains.nix
    ./modules/dms/danksearch.nix
    ./modules/dms/dms.nix
    ./modules/flatpak.nix
  ];
}
