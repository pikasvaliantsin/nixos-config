# «Русская Рыбалка 4» (сайтовая версия) через umu-launcher + GE-Proton.
#
# Ничего не зависит от Steam: umu-launcher сам поднимает Steam Linux Runtime
# и Proton, а слой lsfg-vk (вместе с Lossless.dll) собирается из
# фиксированного релиза.
#
#   rf4-install /путь/к/установщику.exe   — однократная установка игры
#   rf4                                    — игра: Xwayland + lsfg 2x
#   rf4-gamescope                          — 1680x720 + FSR + lsfg 2x (апскейл)
#   rf4-native                             — псевдоним rf4
#   bite-alarm                             — звук при появлении значка рыбки
#
# Префикс: ~/Games/rf4 (внутри Proton использует ~/Games/rf4/pfx).

{ pkgs, lib, ... }:

let
  lsfgVersion = "2.0.0-dev25-p11";

  lsfgSrc = pkgs.fetchurl {
    url = "https://github.com/Castro-Fidel/vulkan/releases/download/lsfg-vk-${lsfgVersion}/lsfg-vk-${lsfgVersion}.tar.xz";
    hash = "sha256-9iGovfFQzHihaGPiyCd9EP10ZJfvnUB7azvN7vwmACI=";
  };

  # Официальный установщик сайтовой версии (зеркало begetcdn).
  installer = pkgs.fetchurl {
    url = "https://goduehuehajugen.begetcdn.cloud/rf4/RF4SetupRU.exe";
    hash = "sha256-1oVFS2egvnDpX+sFe080ii995mWeZxinNBVsAQWUdtE=";
    name = "RF4SetupRU.exe";
  };

  lsfg = pkgs.stdenvNoCC.mkDerivation {
    pname = "lsfg-vk";
    version = lsfgVersion;
    src = lsfgSrc;

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib $out/share/lsfg $out/share/vulkan/implicit_layer.d
      install -m755 liblsfg-vk-layer.so $out/lib/
      install -m644 Lossless.dll $out/share/lsfg/
      cat > $out/share/vulkan/implicit_layer.d/VkLayer_LSFGVK_frame_generation.json <<'JSON'
      {
        "file_format_version": "1.1.0",
        "layer": {
          "name": "VK_LAYER_LSFGVK_frame_generation",
          "description": "Lossless Scaling frame generation layer",
          "implementation_version": "2",
          "library_path": "__OUT__/lib/liblsfg-vk-layer.so",
          "type": "GLOBAL",
          "api_version": "1.4.328",
          "disable_environment": { "DISABLE_LSFGVK": "1" }
        }
      }
      JSON
      substituteInPlace $out/share/vulkan/implicit_layer.d/VkLayer_LSFGVK_frame_generation.json \
        --replace-fail "__OUT__" "$out"
      runHook postInstall
    '';
  };

  proton = pkgs.proton-ge-bin.steamcompattool;
  prefix = "$HOME/Games/rf4";
  umu = lib.getExe pkgs.umu-launcher;

  # Общее окружение для установщика и запуска.
  commonEnv = ''
    export PROTONPATH="${proton}"
    export GAMEID="0"
    export WINEPREFIX="${prefix}"

    # Твои твики DXVK. tearFree (FIFO) нужен для lsfg, заодно убирает разрывы.
    export DXVK_CONFIG="d3d11.samplerAnisotropy=0;d3d11.maxTessFactor=0;d3d11.disableMsaa=True;dxvk.maxChunkSize=32;dxvk.gpl=True;dxgi.tearFree=True"

    # Лаунчер RF4 — это QtWebEngine (Chromium). Под Wine он инициализирует
    # D3D11 через DXVK/Vulkan, и слой lsfg в этом процессе роняет heap
    # (malloc: smallbin double linked list corrupted). Лаунчеру GPU не нужен.
    export QTWEBENGINE_CHROMIUM_FLAGS="--disable-gpu --disable-gpu-compositing --disable-features=Vulkan''${QTWEBENGINE_CHROMIUM_FLAGS:+ $QTWEBENGINE_CHROMIUM_FLAGS}"
  '';

  # Окружение генератора кадров (только для rf4; rf4-native его не получает).
  lsfgEnv = ''
    # Слой lsfg-vk и его DLL (DLL можно переопределить через RF4_LOSSLESS_DLL).
    export XDG_DATA_DIRS="${lsfg}/share''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
    export LSFGVK_ENV="1"
    export LSFGVK_DLL_PATH="''${RF4_LOSSLESS_DLL:-${lsfg}/share/lsfg/Lossless.dll}"
    export LSFGVK_MULTIPLIER="''${RF4_LSFG_MULTIPLIER:-2}"
    export LSFGVK_FLOW_SCALE="''${RF4_LSFG_FLOW_SCALE:-0.6}"
    export LSFGVK_PERFORMANCE_MODE="1"

    # Выключить генерацию, оставив gamescope+FSR: RF4_LSFG=0 rf4
    if [ "''${RF4_LSFG:-1}" = "0" ]; then
      export DISABLE_LSFGVK="1"
    fi
  '';

  # Поиск лаунчера (установщик может положить игру в другой каталог).
  findExe = ''
    exe="${prefix}/pfx/drive_c/Games/RF4/RF4Launcher.exe"
    if [ ! -f "$exe" ]; then
      exe=$(find "${prefix}/pfx/drive_c" -maxdepth 4 -iname 'RF4Launcher.exe' 2>/dev/null | head -n1 || true)
    fi
    if [ -z "''${exe:-}" ] || [ ! -f "$exe" ]; then
      echo "RF4 не установлена в ${prefix}" >&2
      echo "Сначала: rf4-install" >&2
      exit 1
    fi
  '';

  # Основной режим: Xwayland + генерация кадров 2x.
  #
  #   rf4                             — Xwayland + lsfg 2x (по умолчанию)
  #   env RF4_LSFG=0 rf4              — без генерации
  #   env RF4_LSFG_MULTIPLIER=3 rf4
  #   env RF4_WAYLAND=1 rf4           — через winewayland (с lsfg нестабилен)
  rf4 = pkgs.writeShellScriptBin "rf4" ''
    set -eu
    ${commonEnv}

    ${findExe}

    # MangoHud не переживает запуск через umu/pressure-vessel, поэтому FPS
    # показываем средствами DXVK (базовый FPS игры):
    #   RF4_HUD=fps — включён, RF4_HUD= — выключен.
    export DXVK_HUD="''${RF4_HUD-fps}"

    # Слой lsfg-vk падает в презентации через Wayland-WSI
    # (wsi_wl_swapchain_queue_present -> vk_drm_syncobj_wait_many),
    # поэтому по умолчанию Xwayland. Wayland включается вручную:
    #   RF4_WAYLAND=1 rf4
    if [ "''${RF4_WAYLAND:-0}" = "1" ]; then
      export PROTON_ENABLE_WAYLAND="1"
    fi

    # Для плавности нужен VRR; включаем на выходе монитора (RF4_VRR=0 — не трогать).
    if [ "''${RF4_VRR:-1}" = "1" ] && command -v niri >/dev/null 2>&1; then
      niri msg output "''${RF4_OUTPUT:-HDMI-A-1}" vrr on >/dev/null 2>&1 || true
    fi

    ${lsfgEnv}

    exec ${umu} "$exe"
  '';

  # Старое имя основного режима — оставлено для совместимости.
  rf4-native = pkgs.writeShellScriptBin "rf4-native" ''
    exec ${rf4}/bin/rf4 "$@"
  '';

  # Апскейл 1680x720 -> 2240x960 через gamescope + FSR, плюс lsfg 2x.
  # gamescope запускается через security-wrapper с CAP_SYS_NICE: без него
  # композитор пейсит кадры с обычным приоритетом и картинка рвётся.
  #
  #   rf4-gamescope                      — FSR + lsfg 2x + MangoHud
  #   env RF4_LSFG=0 rf4-gamescope       — без генерации
  #   env RF4_GS_FILTER=sgsr rf4-gamescope
  rf4-gamescope = pkgs.writeShellScriptBin "rf4-gamescope" ''
    set -eu
    ${commonEnv}
    ${lsfgEnv}

    ${findExe}

    # Счётчик FPS рисует MangoHud (gamescope --mangoapp), DXVK HUD не нужен.
    unset DXVK_HUD

    # gamescope ищет mangoapp в PATH.
    export PATH="${lib.makeBinPath [ pkgs.mangohud ]}:$PATH"

    # VRR на выходе монитора.
    if [ "''${RF4_VRR:-1}" = "1" ] && command -v niri >/dev/null 2>&1; then
      niri msg output "''${RF4_OUTPUT:-HDMI-A-1}" vrr on >/dev/null 2>&1 || true
    fi

    # Wrapper с cap_sys_nice; если его нет — обычный бинарь из store.
    GS="/run/wrappers/bin/gamescope"
    if [ ! -x "$GS" ]; then
      GS="${lib.getExe pkgs.gamescope}"
    fi

    GS_W="''${RF4_GS_W:-1680}"
    GS_H="''${RF4_GS_H:-720}"
    GS_R="''${RF4_GS_R:-120}"
    GS_FILTER="''${RF4_GS_FILTER:-fsr}"
    GS_SHARP="''${RF4_GS_SHARPNESS:-5}"

    ARGS=(-w "$GS_W" -h "$GS_H" -W 2240 -H 960 -r "$GS_R" -S "''${RF4_GS_SCALER:-fit}")
    if [ "$GS_FILTER" != "none" ]; then
      ARGS+=(-F "$GS_FILTER" --fsr-sharpness "$GS_SHARP")
    fi
    if [ -n "''${RF4_GS_LIMIT:-}" ]; then
      ARGS+=(--framerate-limit "$RF4_GS_LIMIT")
    fi
    if [ "''${RF4_GS_ADAPTIVE:-1}" = "1" ]; then
      ARGS+=(--adaptive-sync)
    fi

    exec "$GS" "''${ARGS[@]}" -f --force-grab-cursor --mangoapp -- ${umu} "$exe"
  '';

  # Звуковой сигнал при появлении значка рыбки. Только grim + звук,
  # в игру не вмешивается и ввод не эмулирует.
  bite-alarm = pkgs.writeShellScriptBin "bite-alarm" ''
    export PATH="${lib.makeBinPath [ pkgs.grim pkgs.pipewire ]}:$PATH"
    exec ${pkgs.python3}/bin/python3 ${./bite-alarm.py} "$@"
  '';

  # Включить/выключить сигнал (биндится на Mod+Alt+B).
  bite-alarm-toggle = pkgs.writeShellScriptBin "bite-alarm-toggle" ''
    set -eu
    if ${pkgs.procps}/bin/pgrep -f "[b]ite-alarm\.py$" >/dev/null 2>&1; then
      ${pkgs.procps}/bin/pkill -f "[b]ite-alarm\.py$" || true
      ${bite-alarm}/bin/bite-alarm --beep --double
      dms ipc call toast info "Bite alarm: выключен" >/dev/null 2>&1 || true
    else
      mkdir -p "$HOME/.cache/bite-alarm"
      ${pkgs.util-linux}/bin/setsid ${bite-alarm}/bin/bite-alarm \
        >"$HOME/.cache/bite-alarm/alarm.log" 2>&1 </dev/null &
      ${bite-alarm}/bin/bite-alarm --beep
      dms ipc call toast info "Bite alarm: включён" >/dev/null 2>&1 || true
    fi
  '';

  rf4-install = pkgs.writeShellScriptBin "rf4-install" ''
    set -eu
    ${commonEnv}

    mkdir -p "$HOME/Games"
    installer="''${1:-''${RF4_INSTALLER:-}}"
    if [ -z "$installer" ]; then
      # Берём зафиксированный в Nix установщик и копируем в записываемое место.
      installer="$HOME/Games/RF4SetupRU.exe"
      cp -f "${installer}" "$installer"
      chmod u+w "$installer"
    fi
    if [ ! -f "$installer" ]; then
      echo "Установщик не найден: $installer" >&2
      exit 1
    fi

    exec ${umu} "$installer"
  '';
in
{
  home.packages = [
    pkgs.umu-launcher
    rf4
    rf4-native
    rf4-gamescope
    rf4-install
    bite-alarm
    bite-alarm-toggle
  ];

  # Иконка игры (извлечена из RF4Launcher.exe).
  home.file.".local/share/icons/hicolor/256x256/apps/rf4.png".source = ./rf4.png;

  # DMS для app-id вида steam_app_N игнорирует Icon из .desktop и всегда ищет
  # иконку темы с именем steam_icon_N. GAMEID=0 → steam_icon_0.
  home.file.".local/share/icons/hicolor/256x256/apps/steam_icon_0.png" = {
    source = ./rf4.png;
    force = true;
  };

  xdg.enable = true;

  # DMS подменяет app-id "steam_app_0" на "steam_icon_0" (см. appIdSubstitutions),
  # поэтому desktop-файл называется так же — тогда док находит имя и иконку.
  xdg.desktopEntries."steam_icon_0" = {
    name = "Russian Fishing 4";
    genericName = "Fishing simulator";
    comment = "Русская Рыбалка 4 (сайтовая версия) через umu + GE-Proton";
    exec = "rf4";
    icon = "rf4";
    terminal = false;
    categories = [ "Game" ];
    type = "Application";
    startupNotify = true;
  };
}
