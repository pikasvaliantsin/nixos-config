{ config, pkgs, inputs, ... }:

{
  imports = [
    ./modules/core.nix
    ./modules/shell.nix
    ./modules/git.nix
    ./modules/terminal.nix
    ./modules/programs.nix
    ./modules/packages.nix
    ./modules/editors.nix
  ];
}
