# Farming Simulator 25 (InsaneRamZes / RUNE) через umu-launcher + GE-Proton.
#
# Как rf4.nix: Steam не нужен, umu сам поднимает Steam Linux Runtime и Proton.
# Игра уже распакована в ~/Games/Farming Simulator 25-InsaneRamZes, префикс
# создаётся в ~/Games/fs25 при первом запуске.
#
# Слой lsfg-vk доступен (тот же релиз Castro-Fidel, что у RF4), но по
# умолчанию ВЫКЛЮЧЕН: у FS25 свой FSR 3.0 + Frame Generation, который
# корректно смешивает UI, а lsfg в меню даёт ghosting.
#
#   fs25                    — игра: Xwayland + MangoHud (FSR3/FG из game.xml)
#   fs25-gamescope          — 1680x720 + NIS + MangoHud
#   env FS25_LSFG=1 fs25    — дополнительно lsfg-vk 2x (FSR3 FG тогда выключить)
#   env FS25_HUD=0 fs25     — без счётчика FPS
#
# FS25 рендерится через D3D12 (vkd3d-proton), поэтому DXVK_CONFIG здесь не
# влияет на презентацию. Для lsfg критичен FIFO: в game.xml нужен vsync=true,
# иначе слой сломает swapchain (на FS25 по умолчанию vsync включён).

{ pkgs, lib, ... }:

let
  lsfgVersion = "2.0.0-dev25-p11";

  lsfgSrc = pkgs.fetchurl {
    url = "https://github.com/Castro-Fidel/vulkan/releases/download/lsfg-vk-${lsfgVersion}/lsfg-vk-${lsfgVersion}.tar.xz";
    hash = "sha256-9iGovfFQzHihaGPiyCd9EP10ZJfvnUB7azvN7vwmACI=";
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
  prefix = "$HOME/Games/fs25";
  gameDir = "$HOME/Games/Farming Simulator 25-InsaneRamZes";
  # AppID FS25; umu превращает GAMEID=umu-<id> в SteamAppId <id>
  # (окно steam_app_2300320, иконка steam_icon_2300320).
  appid = "2300320";
  umu = lib.getExe pkgs.umu-launcher;

  # Общее окружение для запуска.
  commonEnv = ''
    export PROTONPATH="${proton}"
    export GAMEID="umu-${appid}"
    export WINEPREFIX="${prefix}"

    # Твики DXVK (для возможного D3D11-пути). dxgi.tearFree нужен lsfg.
    export DXVK_CONFIG="d3d11.samplerAnisotropy=0;d3d11.maxTessFactor=0;d3d11.disableMsaa=True;dxvk.maxChunkSize=32;dxvk.gpl=True;dxgi.tearFree=True"
  '';

  # Окружение генератора кадров.
  #
  # По умолчанию lsfg ВЫКЛЮЧЕН: у FS25 есть собственный FSR 3.0 Frame
  # Generation (game.xml: fidelityFxSR30FrameInterpolation=true), который
  # корректно миксует UI. lsfg-vk на интерфейсах/меню даёт ghosting, а внутри
  # gamescope вообще не инициализируется (vkCreateSwapchainKHR).
  #
  # Включить lsfg: FS25_LSFG=1 fs25  (и выключить в игре FSR 3.0 FG, иначе 4x).
  lsfgEnv = ''
    if [ "''${FS25_LSFG:-0}" = "1" ]; then
      # Слой lsfg-vk и его DLL (DLL можно переопределить через FS25_LOSSLESS_DLL).
      export XDG_DATA_DIRS="${lsfg}/share''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
      export LSFGVK_ENV="1"
      export LSFGVK_DLL_PATH="''${FS25_LOSSLESS_DLL:-${lsfg}/share/lsfg/Lossless.dll}"
      export LSFGVK_MULTIPLIER="''${FS25_LSFG_MULTIPLIER:-2}"
      export LSFGVK_FLOW_SCALE="''${FS25_LSFG_FLOW_SCALE:-0.6}"
      export LSFGVK_PERFORMANCE_MODE="1"
    else
      export DISABLE_LSFGVK="1"
    fi
  '';

  # Поиск exe (на случай переименования каталога игры).
  findExe = ''
    exe="${gameDir}/FarmingSimulator2025.exe"
    if [ ! -f "$exe" ]; then
      exe=$(find "$HOME/Games" -maxdepth 2 -iname 'FarmingSimulator2025.exe' 2>/dev/null | head -n1 || true)
    fi
    if [ -z "''${exe:-}" ] || [ ! -f "$exe" ]; then
      echo "Farming Simulator 25 не найден в $HOME/Games" >&2
      exit 1
    fi
  '';

  # Счётчик FPS (MangoHud). Для FS25 это Vulkan-слой, работает и с vkd3d.
  #   FS25_HUD=0            — выключить оверлей
  #   FS25_HUD_CONFIG=...   — произвольный MANGOHUD_CONFIG
  hudEnv = ''
    if [ "''${FS25_HUD:-1}" = "1" ]; then
      export PATH="${lib.makeBinPath [ pkgs.mangohud ]}:$PATH"
      export XDG_DATA_DIRS="${pkgs.mangohud}/share''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
      export MANGOHUD="1"
      if [ -n "''${FS25_HUD_CONFIG:-}" ]; then
        export MANGOHUD_CONFIG="$FS25_HUD_CONFIG"
      fi
    fi
  '';

  # Основной режим: Xwayland, нативный FSR 3.0 из игры + MangoHud.
  #
  #   fs25                                — игра (FSR3/FG из game.xml) + счётчик FPS
  #   env FS25_HUD=0 fs25                 — без оверлея
  #   env FS25_LSFG=1 fs25                — lsfg-vk 2x вместо/вместе с FSR3 FG
  #   env FS25_WAYLAND=1 fs25             — winewayland (с lsfg нестабилен)
  fs25 = pkgs.writeShellScriptBin "fs25" ''
    set -eu
    ${commonEnv}
    ${lsfgEnv}
    ${hudEnv}

    ${findExe}

    # Слой lsfg-vk падает в презентации через Wayland-WSI, поэтому по
    # умолчанию Xwayland. Wayland включается вручную: FS25_WAYLAND=1 fs25
    if [ "''${FS25_WAYLAND:-0}" = "1" ]; then
      export PROTON_ENABLE_WAYLAND="1"
    fi

    # VRR на выходе монитора (FS25_VRR=0 — не трогать).
    if [ "''${FS25_VRR:-1}" = "1" ] && command -v niri >/dev/null 2>&1; then
      niri msg output "''${FS25_OUTPUT:-HDMI-A-1}" vrr on >/dev/null 2>&1 || true
    fi

    exec ${umu} "$exe" "$@"
  '';

  # gamescope-режим (для апскейла низкого внутреннего разрешения).
  #
  # lsfg-vk внутри gamescope НЕ инициализируется
  # (failed to get device proc addr for vkCreateSwapchainKHR), а при
  # включении в игре даёт ghosting в меню. Поэтому по умолчанию только
  # апскейл gamescope (NIS), а генерация кадров — средствами FS25 (FSR3 FG).
  #
  #   fs25-gamescope                      — NIS + MangoHud
  #   env FS25_GS_FILTER=fsr fs25-gamescope
  #   env FS25_GS_W=1280 FS25_GS_H=548 fs25-gamescope
  fs25-gamescope = pkgs.writeShellScriptBin "fs25-gamescope" ''
    set -eu
    ${commonEnv}
    ${lsfgEnv}

    ${findExe}

    # Счётчик FPS рисует MangoHud (gamescope --mangoapp).
    unset DXVK_HUD

    # gamescope ищет mangoapp в PATH.
    export PATH="${lib.makeBinPath [ pkgs.mangohud ]}:$PATH"

    # VRR на выходе монитора.
    if [ "''${FS25_VRR:-1}" = "1" ] && command -v niri >/dev/null 2>&1; then
      niri msg output "''${FS25_OUTPUT:-HDMI-A-1}" vrr on >/dev/null 2>&1 || true
    fi

    GS="/run/wrappers/bin/gamescope"
    if [ ! -x "$GS" ]; then
      GS="${lib.getExe pkgs.gamescope}"
    fi

    GS_W="''${FS25_GS_W:-1680}"
    GS_H="''${FS25_GS_H:-720}"
    GS_R="''${FS25_GS_R:-120}"
    GS_FILTER="''${FS25_GS_FILTER:-nis}"
    GS_SHARP="''${FS25_GS_SHARPNESS:-10}"

    ARGS=(-w "$GS_W" -h "$GS_H" -W 2240 -H 960 -r "$GS_R" -S "''${FS25_GS_SCALER:-fit}")
    if [ "$GS_FILTER" != "none" ]; then
      ARGS+=(-F "$GS_FILTER" --fsr-sharpness "$GS_SHARP")
    fi
    if [ -n "''${FS25_GS_LIMIT:-}" ]; then
      ARGS+=(--framerate-limit "$FS25_GS_LIMIT")
    fi
    if [ "''${FS25_GS_ADAPTIVE:-1}" = "1" ]; then
      ARGS+=(--adaptive-sync)
    fi

    exec "$GS" "''${ARGS[@]}" -f --force-grab-cursor --mangoapp -- ${umu} "$exe" "$@"
  '';
in
{
  home.packages = [
    fs25
    fs25-gamescope
  ];

  # Иконка игры (извлечена из web_data/favicon.ico).
  home.file.".local/share/icons/hicolor/256x256/apps/fs25.png".source = ./fs25.png;

  # DMS для app-id вида steam_app_N ищет иконку steam_icon_N.
  home.file.".local/share/icons/hicolor/256x256/apps/steam_icon_${appid}.png" = {
    source = ./fs25.png;
    force = true;
  };

  xdg.enable = true;

  xdg.desktopEntries."steam_icon_${appid}" = {
    name = "Farming Simulator 25";
    genericName = "Farm simulator";
    comment = "Farming Simulator 25 (RUNE) через umu + GE-Proton, lsfg 2x";
    exec = "fs25";
    icon = "fs25";
    terminal = false;
    categories = [ "Game" ];
    type = "Application";
    startupNotify = true;
  };
}
