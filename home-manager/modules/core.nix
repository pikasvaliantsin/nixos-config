# nixos-config/home-manager/modules/core.nix
{ ... }:

{
  home.username = "valen";
  home.homeDirectory = "/home/valen";
  home.stateVersion = "26.05";
  home.enableNixpkgsReleaseCheck = false;

  programs.home-manager.enable = true;
}
