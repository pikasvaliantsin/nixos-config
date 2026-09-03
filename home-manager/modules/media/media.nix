# nixos-config/home-manager/modules/media/media.nix
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Просмотр изображений
    imv
    loupe

    # Видео-плееры
    mpv
    celluloid

    # Запись экрана / стриминг
    obs-studio
  ];
}
