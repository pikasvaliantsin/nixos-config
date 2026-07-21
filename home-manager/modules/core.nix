{ config, pkgs, ... }:

{
  home.enableNixpkgsReleaseCheck = false;
  home.username = "valen";
  home.homeDirectory = "/home/valen";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;
}
