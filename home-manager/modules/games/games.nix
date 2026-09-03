{
  pkgs,
  config,
  inputs,
  ...
}:

let
  # Скрипт патчинга раскладок клавиатуры в префиксах Proton
  fixSteamLayouts = pkgs.writeShellScriptBin "fix-steam-layouts" ''
        COMPAT_DIR="$HOME/.local/share/Steam/steamapps/compatdata"

        if [ -d "$COMPAT_DIR" ]; then
          for pfx in "$COMPAT_DIR"/*/pfx/user.reg; do
            if [ -f "$pfx" ]; then
              if ! grep -q "00000419" "$pfx"; then
                echo "Патчим раскладки в префиксе: $pfx"
                cat << 'EOF' >> "$pfx"

    [HKEY_CURRENT_USER\Keyboard Layout\Preload]
    "1"="00000409"
    "2"="00000419"

    [HKEY_CURRENT_USER\Keyboard Layout\Toggle]
    "Hotkey"="1"
    EOF
              fi
            fi
          done
        fi
  '';
  portprotonQt = pkgs.callPackage ./portproton-qt.nix {};
in
{
  # Переменные для Steam / Gamescope / Wine
  # DISABLE_XIM критичен: ломает фокус и переключение раскладок в Gamescope
  home.sessionVariables = {
    DISABLE_XIM = "1";
    GTK_IM_MODULE = "simple";
    QT_IM_MODULE = "simple";
    XMODIFIERS = "@im=none";

    # Эти переменные уже заданы в hosts/asus-expertbook/niri.nix (системно).
    # Оставлены здесь как fallback для Wine/Gamescope внутри сессии Niri.
    XKB_DEFAULT_LAYOUT = "us,ru";
    XKB_DEFAULT_OPTIONS = "grp:win_space_toggle";
    XKB_CONFIG_ROOT = "${pkgs.xkeyboard_config}/share/X11/xkb";
  };

  # Игровые утилиты и вспомогательные скрипты
  home.packages = with pkgs; [
    gamescope
    protontricks
    mangohud
    fixSteamLayouts
    portprotonQt
  ];

  # Автоматический запуск патчера префиксов при применении конфигурации
  home.activation.fixSteamPrefixes = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    ${fixSteamLayouts}/bin/fix-steam-layouts
  '';
}
