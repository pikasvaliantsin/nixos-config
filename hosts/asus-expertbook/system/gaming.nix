{ pkgs, ... }:

{
  programs = {
    # Системный Steam с расширенным FHS-рантаймом
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
      extraCompatPackages = with pkgs; [
        proton-ge-bin
      ];
      package = pkgs.steam.override {
        extraPkgs = import ./steam-extra-pkgs.nix;
      };
    };

    # GameMode: авто-оптимизация при запуске игр (приоритет, governor, CPU boost)
    # + Gamescope: изоляция игровых процессов от Wayland-композитора
    gamemode = {
      enable = true;
      settings = {
        general = {
          renice = 10; # Приоритет процесса игры
        };
        gpu = {
          gpu_device = 0; # Указываем GPU для Vega 7
        };
      };
    };

    gamescope.enable = true;
  };
}
