{ pkgs, config, ... }:

let
  # Скрипт, который обходит все префиксы Proton в Steam и гарантирует,
  # что в них прописаны клавиатурные раскладки US (00000409) и RU (00000419)
  fixSteamLayouts = pkgs.writeShellScriptBin "fix-steam-layouts" ''
        COMPAT_DIR="$HOME/.local/share/Steam/steamapps/compatdata"

        if [ -d "$COMPAT_DIR" ]; then
          for pfx in "$COMPAT_DIR"/*/pfx/user.reg; do
            if [ -f "$pfx" ]; then
              # Если в реестре префикса еще нет русской раскладки — добавляем
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
in
{
  # 1. Глобальные переменные окружения для Steam / Gamescope / Wine
  home.sessionVariables = {
    # Отключаем XIM, который ломает фокус и переключение раскладок в Gamescope
    DISABLE_XIM = "1";
    GTK_IM_MODULE = "simple";
    QT_IM_MODULE = "simple";
    XMODIFIERS = "@im=none";

    # Передаем Gamescope раскладку клавиатуры и сочетание для переключения (Win + Space)
    XKB_DEFAULT_LAYOUT = "us,ru";
    XKB_DEFAULT_OPTIONS = "grp:win_space_toggle";
    XKB_CONFIG_ROOT = "${pkgs.xkeyboard_config}/share/X11/xkb";
  };

  # 2. Игровые утилиты и вспомогательные скрипты
  home.packages = with pkgs; [
    gamescope # Вейланд-композитор для игр
    protontricks # Управление префиксами Steam
    mangohud # Оверлей FPS / температуры / нагрузки
    fixSteamLayouts # Наш скрипт патчинга префиксов
    protonup-qt
    cartridges
    boilr
    steamcmd
    steam-tui
  ];

  # home.nix
  xdg.desktopEntries.steam = {
    name = "Steam (Light)";
    exec = "steam -no-browser -smallmode %U";
    icon = "steam";
    terminal = false;
    mimeType = [ "x-scheme-handler/steam" ];
  };

  # 3. Автоматический запуск патчера префиксов при применении конфигурации
  home.activation.fixSteamPrefixes = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    ${fixSteamLayouts}/bin/fix-steam-layouts
  '';
}
