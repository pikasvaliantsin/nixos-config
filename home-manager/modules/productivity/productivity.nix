# nixos-config/home-manager/modules/productivity/productivity.nix
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    obsidian
    qbittorrent
    yandex-music
  ];
}
