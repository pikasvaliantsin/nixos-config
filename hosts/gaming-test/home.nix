# Минимальный home для теста RF4.
#
# В отличие от home-manager/home.nix здесь НЕТ nixvim, superwhisper, dux,
# Omarchy/DMS, Zen, Telegram, FS25 и прочих пользовательских модулей.
# Только: core (identity HM), RF4 с единственным профилем rf4-gs,
# Firefox, OpenCode, foot и настройки сессии для gamescope/Xwayland.
{ pkgs, ... }:

{
  imports = [
    ../../home-manager/modules/core.nix
    ../../home-manager/modules/games/rf4.nix
  ];

  home.packages = with pkgs; [
    firefox
    opencode
    foot
    mangohud
    vulkan-tools
    jq
  ];

  # gamescope/Xwayland: та же раскладка и IM-настройки, что в основном конфиге.
  home.sessionVariables = {
    XKB_DEFAULT_LAYOUT = "us,ru";
    XKB_DEFAULT_OPTIONS = "grp:win_space_toggle,compose:menu,ctrl:nocaps";
    DISABLE_XIM = "1";
    GTK_IM_MODULE = "simple";
    QT_IM_MODULE = "simple";
    XMODIFIERS = "@im=none";
  };

  # Конфиг niri для теста лежит в этом хосте, а не в модулях Omarchy.
  xdg.configFile."niri/config.kdl".source = ./niri.kdl;

  xdg.enable = true;
}
