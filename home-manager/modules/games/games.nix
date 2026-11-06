{
  pkgs,
  config,
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
in
{
  home = {
    # Переменные для Steam / Gamescope / Wine
    # DISABLE_XIM критичен: ломает фокус и переключение раскладок в Gamescope
    sessionVariables = {
      DISABLE_XIM = "1";
      GTK_IM_MODULE = "simple";
      QT_IM_MODULE = "simple";
      XMODIFIERS = "@im=none";

    };

    # Игровые утилиты и вспомогательные скрипты
    packages = with pkgs; [
      gamescope
      protontricks
      mangohud
      # Диагностика: vulkaninfo (какой ICD реально используется) и nvtop
      # (загрузка/частоты Vega 7 прямо в терминале).
      vulkan-tools
      nvtopPackages.amd
      # Маппинг виртуального геймпада Moonlight на клавиатуру/мышь
      antimicrox
      fixSteamLayouts
    ];

    # Автоматический запуск патчера префиксов при применении конфигурации
    activation.fixSteamPrefixes = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      ${fixSteamLayouts}/bin/fix-steam-layouts
    '';
  };

  # input-remapper — системный демон, но config_dir он узнаёт только от
  # пользовательского процесса. При логине сообщаем ему каталог конфигурации
  # и запускаем autoload; дальше udev-правило подхватывает виртуальный
  # геймпад Sunshine при подключении телефона.
  systemd.user.services.input-remapper-autoload = {
    Unit = {
      Description = "Autoload input-remapper presets";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.input-remapper}/bin/input-remapper-control --command autoload";
      RemainAfterExit = true;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
