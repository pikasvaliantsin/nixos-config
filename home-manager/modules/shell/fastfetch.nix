# Fastfetch: приветствие при старте интерактивного Fish.
# Конфиг — адаптированный Omarchy-шаблон под NixOS/niri; живёт в репозитории,
# поэтому правки видны без пересборки.
{ config, pkgs, ... }:

{
  home.packages = [ pkgs.fastfetch ];

  xdg.configFile."fastfetch/config.jsonc".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.mySystem.dotfilesRoot}/home-manager/modules/shell/fastfetch/config.jsonc";
}
