# «Русская Рыбалка 4» (сайтовая версия) через umu-launcher + GE-Proton.
#
# Ничего не зависит от Steam: umu-launcher сам поднимает Steam Linux Runtime
# и Proton, а слой lsfg-vk (вместе с Lossless.dll) собирается из
# фиксированного релиза.
#
#   rf4-install /путь/к/установщику.exe   — однократная установка игры
#   rf4                                    — игра: Wine Wayland + LSFG 2x
#   rf4-gamescope                          — 1680x720 (21:9) + FSR + LSFG 3x
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

    # Xalia — слой доступности Wine. Игре он не нужен, но в Xwayland-
    # варианте (gamescope) запускается отдельным процессом и ест CPU.
    export PROTON_USE_XALIA="0"

    # Твои твики DXVK. tearFree не ставим: с VRR и lsfg он форсирует FIFO
    # и ломает адаптивную синхронизацию (в PortProton dxvk.conf по умолчанию).
    export DXVK_CONFIG="d3d11.samplerAnisotropy=0;d3d11.maxTessFactor=0;d3d11.disableMsaa=True;dxvk.maxChunkSize=32;dxvk.gpl=True"

    # Лаунчер RF4 — это QtWebEngine (Chromium). Под Wine он инициализирует
    # D3D11 через DXVK/Vulkan, и слой lsfg в этом процессе роняет heap
    # (malloc: smallbin double linked list corrupted). Лаунчеру GPU не нужен.
    export QTWEBENGINE_CHROMIUM_FLAGS="--disable-gpu --disable-gpu-compositing --disable-features=Vulkan''${QTWEBENGINE_CHROMIUM_FLAGS:+ $QTWEBENGINE_CHROMIUM_FLAGS}"
  '';

  # Окружение генератора кадров (только для rf4; rf4-native его не получает).
  # Качество важнее множителя: 2x/1.0/без performance даёт заметно меньше
  # «воды», чем PortProton-профиль 3x/0.5/performance. Если базы не хватает,
  # вернуть профиль PortProton: RF4_LSFG_MULTIPLIER=3 RF4_LSFG_FLOW_SCALE=0.5
  # RF4_LSFG_PERFORMANCE_MODE=1.
  lsfgEnv = ''
    # Слой lsfg-vk и его DLL (DLL можно переопределить через RF4_LOSSLESS_DLL).
    export XDG_DATA_DIRS="${lsfg}/share''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
    export LSFGVK_ENV="1"
    export LSFGVK_DLL_PATH="''${RF4_LOSSLESS_DLL:-${lsfg}/share/lsfg/Lossless.dll}"
    export LSFGVK_MULTIPLIER="''${RF4_LSFG_MULTIPLIER:-2}"
    export LSFGVK_FLOW_SCALE="''${RF4_LSFG_FLOW_SCALE:-1.0}"
    export LSFGVK_PERFORMANCE_MODE="''${RF4_LSFG_PERFORMANCE_MODE:-0}"

    # Выключить генерацию, оставив gamescope+FSR: RF4_LSFG=0 rf4
    if [ "''${RF4_LSFG:-1}" = "0" ]; then
      export DISABLE_LSFGVK="1"
    fi
  '';

  # Необязательный MangoHud. Основной счётчик — DXVK_HUD (RF4_HUD), он
  # переживает umu/pressure-vessel. MangoHud полезен для frametime/GPU,
  # но с umu может не подняться, поэтому включается только вручную:
  #   RF4_MANGOHUD=1 rf4
  #   RF4_MANGOHUD=1 RF4_MANGOHUD_CONFIG=fps,frametime,gpu_stats rf4
  hudEnv = ''
    if [ "''${RF4_MANGOHUD:-0}" = "1" ]; then
      export PATH="${lib.makeBinPath [ pkgs.mangohud ]}:$PATH"
      export XDG_DATA_DIRS="${pkgs.mangohud}/share''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
      export MANGOHUD="1"
      export MANGOHUD_CONFIG="''${RF4_MANGOHUD_CONFIG:-fps,frametime,gpu_stats,cpu_stats}"
      # Не дублировать оверлеи: MangoHud заменяет DXVK HUD.
      export DXVK_HUD=""
    fi
  '';

  # Привилегированный тюнинг APU на время игры. Скрипт ставит
  # platform_profile=performance, amdgpu DPM high и swappiness=100,
  # а на выходе возвращает сохранённые значения. sudo -n разрешён
  # только на этот скрипт (см. hosts/asus-expertbook/system/gaming.nix).
  powerTune = ''
    SUDO="/run/wrappers/bin/sudo"
    TUNE_BIN="/run/current-system/sw/bin/game-power-tune"
    if [ "''${RF4_POWER_TUNE:-1}" = "1" ] \
    && [ -x "$SUDO" ] && [ -x "$TUNE_BIN" ] \
    && "$SUDO" -n "$TUNE_BIN" start >/dev/null 2>&1; then
      trap '"$SUDO" -n "$TUNE_BIN" stop >/dev/null 2>&1 || true' EXIT INT TERM HUP
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

  # Unity/RF4 does not follow the compositor's output mode: it reads its own
  # Settings.dat and Unity registry on every start. Write the requested
  # resolution there. Called from rf4 with the monitor mode and from
  # rf4-gamescope with the gamescope internal size (1680x720).
  syncResolutionFn = ''
    sync_rf4_resolution() {
      local w="$1" h="$2"
      [ -n "$w" ] && [ -n "$h" ] || return 0

      local settings tmp reg
      settings="$WINEPREFIX/drive_c/users/steamuser/AppData/Roaming/RussianFishingLLC/RussianFishing4/Settings.dat"
      if [ -f "$settings" ]; then
        tmp=$(mktemp)
        {
          printf '\xEF\xBB\xBF'
          ${pkgs.jq}/bin/jq --argjson w "$w" --argjson h "$h" \
            '.video.screenMode = 0 | .video.screenW = $w | .video.screenH = $h' "$settings" \
            | ${pkgs.gnused}/bin/sed 's/$/\r/'
        } > "$tmp"
        mv "$tmp" "$settings"
      fi

      reg="$WINEPREFIX/user.reg"
      if [ -f "$reg" ]; then
        ${pkgs.gnused}/bin/sed -i \
          -e "s|^\"Screenmanager Resolution Width_h182942802\"=dword:.*|\"Screenmanager Resolution Width_h182942802\"=dword:$(printf '%08x' "$w")|" \
          -e "s|^\"Screenmanager Resolution Width Default_h680557497\"=dword:.*|\"Screenmanager Resolution Width Default_h680557497\"=dword:$(printf '%08x' "$w")|" \
          -e "s|^\"Screenmanager Resolution Height_h2627697771\"=dword:.*|\"Screenmanager Resolution Height_h2627697771\"=dword:$(printf '%08x' "$h")|" \
          -e "s|^\"Screenmanager Resolution Height Default_h1380706816\"=dword:.*|\"Screenmanager Resolution Height Default_h1380706816\"=dword:$(printf '%08x' "$h")|" \
          -e "s|^\"Screenmanager Resolution Window Width_h2524650974\"=dword:.*|\"Screenmanager Resolution Window Width_h2524650974\"=dword:$(printf '%08x' "$w")|" \
          -e "s|^\"Screenmanager Resolution Window Height_h1684712807\"=dword:.*|\"Screenmanager Resolution Window Height_h1684712807\"=dword:$(printf '%08x' "$h")|" \
          -e 's|^"Screenmanager Resolution Use Native_h1405027254"=dword:.*|"Screenmanager Resolution Use Native_h1405027254"=dword:00000000|' \
          -e 's|^"Screenmanager Resolution Use Native Default_h1405981789"=dword:.*|"Screenmanager Resolution Use Native Default_h1405981789"=dword:00000000|' \
          -e 's|^"Screenmanager Fullscreen mode_h3630240806"=dword:.*|"Screenmanager Fullscreen mode_h3630240806"=dword:00000001|' \
          -e 's|^"Screenmanager Fullscreen mode Default_h401710285"=dword:.*|"Screenmanager Fullscreen mode Default_h401710285"=dword:00000001|' \
          "$reg" || true
      fi
    }
  '';

  # Для нативного запуска: физический текущий режим HDMI из niri.
  # Disable with RF4_SYNC_RESOLUTION=0; RF4_OUTPUT selects the niri output.
  syncResolution = ''
    if [ "''${RF4_SYNC_RESOLUTION:-1}" = "1" ] && command -v niri >/dev/null 2>&1; then
      out="''${RF4_OUTPUT:-HDMI-A-1}"
      json=$(niri msg --json outputs 2>/dev/null || true)
      # Физический текущий режим, а не logical: при scale != 1 логический
      # размер меньше, и игра получила бы неверное разрешение.
      w=$(printf '%s' "$json" | ${pkgs.jq}/bin/jq -r --arg out "$out" '.[$out] as $o | ($o.modes[$o.current_mode].width // $o.logical.width) // empty' 2>/dev/null || true)
      h=$(printf '%s' "$json" | ${pkgs.jq}/bin/jq -r --arg out "$out" '.[$out] as $o | ($o.modes[$o.current_mode].height // $o.logical.height) // empty' 2>/dev/null || true)
      sync_rf4_resolution "$w" "$h"
    fi
  '';

  # Основной режим: Wine Wayland, без Gamescope и с генерацией 2x.
  #
  #   rf4                             — Wine Wayland + LSFG 2x (по умолчанию)
  #   env RF4_WAYLAND=0 rf4           — принудительно Xwayland
  #   env RF4_LSFG=0 rf4              — без генерации
  #   env RF4_LSFG_MULTIPLIER=3 RF4_LSFG_FLOW_SCALE=0.5 rf4
  #   env RF4_MANGOHUD=1 rf4          — MangoHud вместо DXVK_HUD
  rf4 = pkgs.writeShellScriptBin "rf4" ''
    set -eu
    ${commonEnv}

    ${findExe}
    ${syncResolutionFn}
    ${syncResolution}

    # MangoHud не переживает запуск через umu/pressure-vessel, поэтому FPS
    # показываем средствами DXVK (базовый FPS игры):
    #   RF4_HUD=fps — включён, RF4_HUD= — выключен.
    #   RF4_HUD=fps,frametimes,gpuload — FPS + график времени кадра + GPU.
    export DXVK_HUD="''${RF4_HUD-fps}"
    ${hudEnv}

    # Xwayland-satellite 0.8.x после смены режима выхода продолжает отдавать
    # старый (issue #251), и RF4 сохраняет 1920x1080. Wine Wayland читает
    # режим напрямую у niri, поэтому он основной. Xwayland: RF4_WAYLAND=0.
    if [ "''${RF4_WAYLAND:-1}" = "1" ]; then
      export PROTON_ENABLE_WAYLAND="1"
      export PROTON_WAYLAND_MONITOR="''${RF4_OUTPUT:-HDMI-A-1}"
    else
      unset PROTON_ENABLE_WAYLAND PROTON_WAYLAND_MONITOR || true
    fi

    # Для плавности нужен VRR; включаем на выходе монитора (RF4_VRR=0 — не трогать).
    if [ "''${RF4_VRR:-1}" = "1" ] && command -v niri >/dev/null 2>&1; then
      niri msg output "''${RF4_OUTPUT:-HDMI-A-1}" vrr on >/dev/null 2>&1 || true
    fi

    # Генерация включена по умолчанию: базовые ~20 FPS иначе выглядят
    # ровно как 20 FPS. Выключить: RF4_LSFG=0 rf4.
    export RF4_LSFG="''${RF4_LSFG:-1}"

    ${lsfgEnv}
    ${powerTune}

    ${umu} "$exe"
  '';

  # Старое имя основного режима — оставлено для совместимости.
  rf4-native = pkgs.writeShellScriptBin "rf4-native" ''
    exec ${rf4}/bin/rf4 "$@"
  '';

  # ========================================
  # ЛОКАЛЬНЫЙ СЕРВЕР (rf4_server_simulator)
  # ========================================
  #
  # Клиент для локалки — отдельная физическая копия префикса
  # (~/Games/rf4-sim), запускается в cgroup rf4sim.slice. nftables-правила
  # (hosts/asus-expertbook/system/rf4sim-guard.nix) заворачивают весь его
  # TCP 443/9341/7515 на 127.0.0.1 и дропают любой трафик вне loopback:
  # подключиться к официальному серверу он не может физически.
  # Лаунчер (и его автообновление) не запускается — только rf4_x64.exe.
  rf4sim = pkgs.writeShellScriptBin "rf4sim" ''
    set -eu
    ${commonEnv}
    export WINEPREFIX="$HOME/Games/rf4-sim"

    # Язык клиента — русский, как в официальном префиксе. Прямой запуск
    # rf4_x64.exe иногда сбрасывает ключ на системный en-US.
    ${pkgs.gnused}/bin/sed -i \
      's|^"Language_h3872303031"=hex:.*|"Language_h3872303031"=hex:72,75,2d,52,55,00|' \
      "$WINEPREFIX/user.reg" 2>/dev/null || true

    if [ "''${RF4SIM_SCOPED:-0}" != "1" ]; then
      export RF4SIM_SCOPED=1
      exec ${lib.getExe' pkgs.systemd "systemd-run"} --user --scope --quiet \
        --slice=rf4sim.slice --unit=rf4sim-game -- "$0" "$@"
    fi

    exe="$WINEPREFIX/drive_c/Games/RF4/Game/rf4_x64.exe"
    if [ ! -f "$exe" ]; then
      echo "Нет $exe — сначала выполни rf4sim-copy" >&2
      exit 1
    fi

    # nft резолвит cgroupv2-путь только когда rf4sim.slice уже существует.
    # Мы внутри scope, слайс есть; ставим guard и снимаем на выходе.
    NETGUARD="/run/current-system/sw/bin/rf4sim-netguard"
    SUDO="/run/wrappers/bin/sudo"
    if [ ! -x "$NETGUARD" ] || ! "$SUDO" -n "$NETGUARD" start >/dev/null 2>&1; then
      echo "rf4sim: не удалось включить сетевую изоляцию (netguard); запуск отменён" >&2
      exit 1
    fi
    trap '"$SUDO" -n "$NETGUARD" stop >/dev/null 2>&1 || true' EXIT INT TERM HUP

    export DXVK_HUD="''${RF4_HUD-fps}"

    # Клиент сайтовой версии требует регион; без него падает
    # Region initialization failed.
    if [ "$#" -eq 0 ]; then
      set -- -region RU
    fi
    ${umu} "$exe" "$@"
  '';

  # Физическая копия клиента (на btrfs — reflink: отдельный inode, экстенты
  # разделяются до первой записи, официальный префикс изменить невозможно).
  # Заодно вычищается официальная сессия/настройки: локальный клиент не
  # должен стартовать с чужим токеном.
  rf4sim-copy = pkgs.writeShellScriptBin "rf4sim-copy" ''
    set -eu
    src="$HOME/Games/rf4"
    dst="$HOME/Games/rf4-sim"

    if [ -e "$dst" ] && [ "''${1:-}" != "--force" ]; then
      echo "$dst уже существует; удали вручную или запусти с --force" >&2
      exit 1
    fi
    if [ "''${1:-}" = "--force" ]; then rm -rf "$dst"; fi

    echo "Копирую $src -> $dst (reflink)..."
    cp -a --reflink=auto "$src" "$dst"

    rm -rf "$dst/drive_c/users/steamuser/AppData/Roaming/RussianFishingLLC"
    rm -rf "$dst/drive_c/users/steamuser/AppData/LocalLow/Russian Fishing LLC"
    rm -rf "$dst/drive_c/users/steamuser/AppData/Local/RF4Launcher"
    rm -rf "$dst/drive_c/users/steamuser/Documents/Russian Fishing 4"
    rm -rf "$dst/drive_c/users/valen/AppData/Roaming/RussianFishingLLC"
    rm -rf "$dst/drive_c/users/valen/AppData/LocalLow/Russian Fishing LLC"
    rm -f "$dst/drive_c/Games/RF4/RF4Launcher.conf" "$dst/drive_c/Games/RF4/Session.conf"
    rm -f "$dst/pfx.lock"
    echo "Готово: $dst"
  '';

  # Импорт локального CA только в префикс локалки (не в систему).
  rf4sim-trust = pkgs.writeShellScriptBin "rf4sim-trust" ''
    set -eu
    ${commonEnv}
    export WINEPREFIX="$HOME/Games/rf4-sim"

    crt="''${1:-$HOME/Games/rf4-sim/certs/server.crt}"
    if [ ! -f "$crt" ]; then
      echo "Нет сертификата $crt" >&2
      exit 1
    fi
    winpath="Z:$(printf '%s' "$crt" | sed 's|/|\\\\|g')"

    exec ${umu} "$WINEPREFIX/drive_c/windows/system32/certutil.exe" \
      -addstore -f Root "$winpath"
  '';

  # Запуск для стрима: Sunshine создаёт виртуальный геймпад уже после старта
  # приложения, а RF4 (Unity/Proton) намертво виснет, если джойстик воткнуть
  # в уже запущенную игру. Ждём появления геймпада (и пары секунд на
  # forwarded-устройство input-remapper), затем запускаем игру.
  rf4-stream = pkgs.writeShellScriptBin "rf4-stream" ''
    set -eu
    i=0
    while [ "$i" -lt 40 ]; do
      if ${pkgs.gnugrep}/bin/grep -q 'Name="Sunshine (libvirtualhid) X-Box Series Controller"' /proc/bus/input/devices 2>/dev/null; then
        # Дать input-remapper создать forwarded-копию геймпада.
        ${pkgs.coreutils}/bin/sleep 2
        break
      fi
      i=$((i + 1))
      ${pkgs.coreutils}/bin/sleep 0.5
    done
    exec ${rf4}/bin/rf4 "$@"
  '';

  # 1680x720 (21:9) -> размер HDMI через gamescope + FSR, плюс lsfg 3x.
  # gamescope запускается через security-wrapper с CAP_SYS_NICE.
  #
  # LSFG must be loaded ONLY in the game, never in gamescope: two copies
  # insert frames twice, then gamescope's fixed refresh skips/tears them.
  # Default profile is tuned for the iGPU (Radeon Vega 7 in Ryzen 5 5625U):
  # 3x / flow 0.5 / performance mode. The base is capped at refresh / multiplier
  # (40 FPS for 3x on 120 Hz) so LSFG and gamescope present a stable stream;
  # without the cap the game outruns generation and gamescope drops frames.
  # 4x raised nominal output but lowered base FPS and felt less responsive.
  # VRR on; no MangoHud by default.
  # The RF4 launcher is designed for 16:9; if its bottom buttons are cut
  # off at 720p, launch the game directly (launcher only for login/updates).
  #
  #   rf4-gamescope
  #   env RF4_LSFG=0 rf4-gamescope          — без генерации
  #   env RF4_GS_FILTER=sgsr rf4-gamescope
  #   env RF4_GS_W=1600 RF4_GS_H=900 rf4-gamescope — внутреннее 16:9
  #   env RF4_GS_OUT_W=1920 RF4_GS_OUT_H=1080 rf4-gamescope — другой выход
  #   env RF4_GS_ADAPTIVE=0 RF4_VRR=0 rf4-gamescope — выключить VRR
  #   env RF4_GS_MANGO=0 rf4-gamescope      — выключить MangoHud (FPS)
  #   env RF4_GS_MANGOHUD_CONFIG=fps,frametime rf4-gamescope
  #   env RF4_GS_HUD=1 RF4_HUD=fps rf4-gamescope — лёгкий DXVK HUD (базовый FPS)
  rf4-gamescope = pkgs.writeShellScriptBin "rf4-gamescope" ''
    set -eu
    ${commonEnv}
    ${syncResolutionFn}
    ${lsfgEnv}

    # 1680x720 + FSR на Vega 7 (5625U): 3x / flow 0.5 / performance.
    # База ограничена refresh/multiplier (40 FPS для 3x на 120 Гц), иначе
    # игра обгоняет генерацию и gamescope выбрасывает кадры.
    export LSFGVK_MULTIPLIER="''${RF4_LSFG_MULTIPLIER:-3}"
    export LSFGVK_FLOW_SCALE="''${RF4_LSFG_FLOW_SCALE:-0.5}"
    export LSFGVK_PERFORMANCE_MODE="''${RF4_LSFG_PERFORMANCE_MODE:-1}"
    MULT="''${RF4_LSFG_MULTIPLIER:-3}"
    if ! [[ "$MULT" =~ ^[1-9][0-9]*$ ]]; then MULT=3; fi

    ${findExe}
    ${powerTune}

    # LSFG включён только для игры. gamescope получает жёсткий disable,
    # а команда после -- снимает его обратно для umu/Wine.
    LSFG_OFF="''${DISABLE_LSFGVK:-0}"

    GAME_ENV=(${pkgs.coreutils}/bin/env)
    GAME_ENV+=(-u VK_LOADER_LAYERS_DISABLE)
    if [ "$LSFG_OFF" = "1" ]; then
      GAME_ENV+=(DISABLE_LSFGVK=1)
    else
      GAME_ENV+=(-u DISABLE_LSFGVK)
    fi
    GAME_ENV+=(ENABLE_GAMESCOPE_WSI=0)
    if [ "$LSFG_OFF" != "1" ]; then
      # Re-assert the layer environment for the child: gamescope can filter
      # or rewrite its environment, and the implicit layer needs both the
      # manifest path and the opt-in variable to be present.
      GAME_ENV+=(
        LSFGVK_ENV=1
        "XDG_DATA_DIRS=$XDG_DATA_DIRS"
        "LSFGVK_DLL_PATH=$LSFGVK_DLL_PATH"
        "LSFGVK_MULTIPLIER=$LSFGVK_MULTIPLIER"
        "LSFGVK_FLOW_SCALE=$LSFGVK_FLOW_SCALE"
        "LSFGVK_PERFORMANCE_MODE=$LSFGVK_PERFORMANCE_MODE"
      )
    fi

    # VRR/adaptive sync включён по умолчанию: LSFG редко попадает ровно
    # в 120, и без VRR разница 100–120 ощущается как ступеньки. Отключить:
    # RF4_GS_ADAPTIVE=0 RF4_VRR=0.
    if command -v niri >/dev/null 2>&1; then
      if [ "''${RF4_VRR:-1}" = "1" ] || [ "''${RF4_GS_ADAPTIVE:-1}" = "1" ]; then
        niri msg output "''${RF4_OUTPUT:-HDMI-A-1}" vrr on >/dev/null 2>&1 || true
      else
        niri msg output "''${RF4_OUTPUT:-HDMI-A-1}" vrr off >/dev/null 2>&1 || true
      fi
    fi

    # Wrapper с cap_sys_nice; если его нет — обычный бинарь из store.
    GS="/run/wrappers/bin/gamescope"
    if [ ! -x "$GS" ]; then
      GS="${lib.getExe pkgs.gamescope}"
    fi

    GS_W="''${RF4_GS_W:-1680}"
    GS_H="''${RF4_GS_H:-720}"
    # Игра должна видеть ровно тот размер, который рендерит gamescope:
    # иначе RF4 остаётся в 2240x960 из нативного запуска и просит лишнее.
    if [ "''${RF4_GS_SYNC_RESOLUTION:-1}" = "1" ]; then
      sync_rf4_resolution "$GS_W" "$GS_H"
    fi
    # Output follows the niri HDMI physical mode, so a mode change in the
    # Display panel does not need RF4_GS_OUT_* overrides.
    niri_w=""
    niri_h=""
    if command -v niri >/dev/null 2>&1; then
      json=$(niri msg --json outputs 2>/dev/null || true)
      niri_w=$(printf '%s' "$json" | ${pkgs.jq}/bin/jq -r --arg out "''${RF4_OUTPUT:-HDMI-A-1}" '.[$out] as $o | ($o.modes[$o.current_mode].width // $o.logical.width) // empty' 2>/dev/null || true)
      niri_h=$(printf '%s' "$json" | ${pkgs.jq}/bin/jq -r --arg out "''${RF4_OUTPUT:-HDMI-A-1}" '.[$out] as $o | ($o.modes[$o.current_mode].height // $o.logical.height) // empty' 2>/dev/null || true)
    fi
    GS_OUT_W="''${RF4_GS_OUT_W:-}"
    GS_OUT_H="''${RF4_GS_OUT_H:-}"
    [ -n "$GS_OUT_W" ] || GS_OUT_W="''${niri_w:-1920}"
    [ -n "$GS_OUT_H" ] || GS_OUT_H="''${niri_h:-1080}"
    GS_R="''${RF4_GS_R:-120}"
    GS_FILTER="''${RF4_GS_FILTER:-fsr}"
    GS_SHARP="''${RF4_GS_SHARPNESS:-5}"

    # Ограничение базового FPS: сгенерированные кадры должны укладываться
    # в refresh выхода. Без этого игра рисует выше 1/N refresh, LSFG
    # перегенерирует, а gamescope выбрасывает лишние кадры (рывки).
    if [ "$LSFG_OFF" = "1" ]; then
      GS_LIMIT="''${RF4_GS_LIMIT:-0}"
    else
      GS_LIMIT="''${RF4_GS_LIMIT:-$((GS_R / MULT))}"
    fi
    if [ -n "$GS_LIMIT" ] && [ "$GS_LIMIT" != "0" ] && [ "$GS_LIMIT" != "off" ] && [ "$LSFG_OFF" != "1" ]; then
      export DXVK_CONFIG="$DXVK_CONFIG;dxgi.maxFrameRate=$GS_LIMIT"
    fi

    ARGS=(-w "$GS_W" -h "$GS_H" -W "$GS_OUT_W" -H "$GS_OUT_H" -r "$GS_R" -S "''${RF4_GS_SCALER:-fit}")
    ARGS+=(--framerate-limit "$GS_R")
    if [ "$GS_FILTER" != "none" ]; then
      ARGS+=(-F "$GS_FILTER" --fsr-sharpness "$GS_SHARP")
    fi

    if [ "''${RF4_GS_ADAPTIVE:-1}" = "1" ]; then
      ARGS+=(--adaptive-sync)
    fi
    # MangoHud через gamescope: единственный счётчик, который показывает
    # output FPS (с учётом LSFG), а не базовый FPS игры. Выключить:
    # RF4_GS_MANGO=0 rf4-gamescope.
    if [ "''${RF4_GS_MANGO:-1}" = "1" ]; then
      export PATH="${lib.makeBinPath [ pkgs.mangohud ]}:$PATH"
      export MANGOHUD_CONFIG="''${RF4_GS_MANGOHUD_CONFIG:-fps}"
      ARGS+=(--mangoapp)
    fi

    # Счётчик без тяжёлого MangoHud: DXVK HUD внутри игры.
    #   RF4_GS_HUD=1 RF4_HUD=fps rf4-gamescope
    if [ "''${RF4_GS_HUD:-0}" = "1" ]; then
      export DXVK_HUD="''${RF4_HUD:-fps}"
    else
      unset DXVK_HUD
    fi

    ${pkgs.coreutils}/bin/env \
      DISABLE_LSFGVK=1 \
      VK_LOADER_LAYERS_DISABLE=VK_LAYER_LSFGVK_frame_generation \
      "$GS" "''${ARGS[@]}" -f --force-grab-cursor -- "''${GAME_ENV[@]}" \
      ${umu} "$exe"
  '';

  # D-pad -> F13–F16 (input-remapper), демон превращает их в XTEST-колесо.
  # Виртуальная мышь input-remapper не доходила до Unity/RF4, а XTEST
  # (как физическая мышь) работает.
  rf4-wheel-xtest = pkgs.writeShellScriptBin "rf4-wheel-xtest" ''
    export PATH="${pkgs.xdotool}/bin:$PATH"
    exec ${pkgs.python3.withPackages (ps: [ ps.evdev ])}/bin/python3 ${./rf4-wheel-xtest.py}
  '';

  # Звуковой сигнал при появлении значка рыбки. Только grim + звук,
  # в игру не вмешивается и ввод не эмулирует.
  bite-alarm = pkgs.writeShellScriptBin "bite-alarm" ''
    export PATH="${
      lib.makeBinPath [
        pkgs.grim
        pkgs.pipewire
      ]
    }:$PATH"
    exec ${pkgs.python3}/bin/python3 ${./bite-alarm.py} "$@"
  '';

  # Включить/выключить сигнал (биндится на Mod+Alt+B).
  bite-alarm-toggle = pkgs.writeShellScriptBin "bite-alarm-toggle" ''
    set -eu
    if ${pkgs.procps}/bin/pgrep -f "[b]ite-alarm\.py$" >/dev/null 2>&1; then
      ${pkgs.procps}/bin/pkill -f "[b]ite-alarm\.py$" || true
      ${bite-alarm}/bin/bite-alarm --beep --double
      notify-send -a "RF4" "Bite alarm: выключен" >/dev/null 2>&1 || true
    else
      mkdir -p "$HOME/.cache/bite-alarm"
      ${pkgs.util-linux}/bin/setsid ${bite-alarm}/bin/bite-alarm \
        >"$HOME/.cache/bite-alarm/alarm.log" 2>&1 </dev/null &
      ${bite-alarm}/bin/bite-alarm --beep
      notify-send -a "RF4" "Bite alarm: включён" >/dev/null 2>&1 || true
    fi
  '';

  # Удержание клавиши [ (альтернативная ЛКМ) для равномерной проводки.
  # Mod+Alt+R — включить/выключить. Удержание идёт через uinput (физический
  # keycode, не зависит от раскладки). reel-watch.py снимает удержание, если
  # ты сам нажал [.
  reel-hold = pkgs.writeShellScriptBin "reel-hold" ''
    set -eu
    export PATH="${lib.makeBinPath [ pkgs.coreutils ]}:$PATH"
    export REEL_KEYCODE="''${REEL_KEYCODE:-26}"
    STATE="''${XDG_RUNTIME_DIR:-/tmp}/reel-hold"
    PIDFILE="$STATE.pid"
    WATCHPID="$STATE.watch"

    release() {
      if [ -e "$WATCHPID" ]; then
        kill "$(cat "$WATCHPID")" 2>/dev/null || true
        rm -f "$WATCHPID"
      fi
      if [ -e "$PIDFILE" ]; then
        kill "$(cat "$PIDFILE")" 2>/dev/null || true
        rm -f "$PIDFILE"
      fi
      rm -f "$STATE"
    }

    case "''${1:-}" in
      --off)
        release
        notify-send -a "RF4" "Проводка: выключена" >/dev/null 2>&1 || true
        ;;
      *)
        if [ -e "$STATE" ]; then
          release
          notify-send -a "RF4" "Проводка: выключена" >/dev/null 2>&1 || true
        else
          : > "$STATE"
          mkdir -p "$HOME/.cache"
          ${pkgs.util-linux}/bin/setsid ${pkgs.python3}/bin/python3 \
            ${./reel-hold-daemon.py} >"$HOME/.cache/reel-hold.log" 2>&1 </dev/null &
          echo $! > "$PIDFILE"
          sleep 0.3
          ${pkgs.util-linux}/bin/setsid ${pkgs.python3}/bin/python3 \
            ${./reel-watch.py} >"$HOME/.cache/reel-watch.log" 2>&1 </dev/null &
          echo $! > "$WATCHPID"
          notify-send -a "RF4" "Проводка: удержание" >/dev/null 2>&1 || true
        fi
        ;;
    esac
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
    rf4sim
    rf4sim-copy
    rf4sim-trust
    rf4-stream
    rf4-gamescope
    rf4-wheel-xtest
    rf4-install
    bite-alarm
    bite-alarm-toggle
    reel-hold
  ];

  # Иконка игры (извлечена из RF4Launcher.exe).
  home.file.".local/share/icons/hicolor/256x256/apps/rf4.png".source = ./rf4.png;

  # DMS для app-id вида steam_app_N игнорирует Icon из .desktop и всегда ищет
  # иконку темы с именем steam_icon_N. GAMEID=0 → steam_icon_0.
  home.file.".local/share/icons/hicolor/256x256/apps/steam_icon_0.png" = {
    source = ./rf4.png;
    force = true;
  };

  systemd.user.services.rf4-wheel-xtest = {
    Unit = {
      Description = "RF4 gamepad D-pad -> XTEST wheel";
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${rf4-wheel-xtest}/bin/rf4-wheel-xtest";
      Environment = [ "DISPLAY=:0" ];
      Restart = "always";
      RestartSec = 1;
    };
    Install.WantedBy = [ "graphical-session.target" ];
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

  # Отдельный ярлык для gamescope-профиля: 1680x720 + FSR + LSFG.
  # Окно gamescope имеет app-id "gamescope", поэтому привязываем его
  # через StartupWMClass, чтобы док показывал имя и иконку RF4.
  xdg.desktopEntries."rf4-gamescope" = {
    name = "Russian Fishing 4 (Gamescope)";
    genericName = "Fishing simulator";
    comment = "Русская Рыбалка 4 через gamescope: 1680x720 + FSR + LSFG";
    exec = "rf4-gamescope";
    icon = "rf4";
    terminal = false;
    categories = [ "Game" ];
    type = "Application";
    startupNotify = true;
    settings = {
      StartupWMClass = "gamescope";
    };
  };
}
