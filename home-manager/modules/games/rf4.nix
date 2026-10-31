# «Русская Рыбалка 4» (сайтовая версия) через umu-launcher + GE-Proton.
#
# Ничего не зависит от Steam: umu-launcher сам поднимает Steam Linux Runtime
# и Proton, а слой lsfg-vk (вместе с Lossless.dll) собирается из
# фиксированного релиза.
#
#   rf4-install /путь/к/установщику.exe   — однократная установка игры
#   rf4                                    — запуск (gamescope + lsfg + MangoHud)
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

  lsfg = pkgs.stdenvNoCC.mkDerivation {    pname = "lsfg-vk";
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
  gamescope = lib.getExe pkgs.gamescope;

  # Общее окружение для установщика и запуска.
  commonEnv = ''
    export PROTONPATH="${proton}"
    export GAMEID="0"
    export WINEPREFIX="${prefix}"

    # Слой lsfg-vk и его DLL (DLL можно переопределить через RF4_LOSSLESS_DLL).
    export XDG_DATA_DIRS="${lsfg}/share''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
    export LSFGVK_ENV="1"
    export LSFGVK_DLL_PATH="''${RF4_LOSSLESS_DLL:-${lsfg}/share/lsfg/Lossless.dll}"
    export LSFGVK_MULTIPLIER="4"
    export LSFGVK_FLOW_SCALE="0.5"
    export LSFGVK_PERFORMANCE_MODE="1"

    # FIFO обязателен для lsfg; остальное — твои твики DXVK.
    export DXVK_CONFIG="d3d11.samplerAnisotropy=0;d3d11.maxTessFactor=0;d3d11.disableMsaa=True;dxvk.maxChunkSize=32;dxvk.gpl=True;dxgi.tearFree=True"

    # gamescope ищет mangohud в PATH для --mangoapp.
    export PATH="${lib.makeBinPath [ pkgs.mangohud ]}:$PATH"
  '';

  rf4 = pkgs.writeShellScriptBin "rf4" ''
    set -eu
    ${commonEnv}

    exe="${prefix}/pfx/drive_c/Games/RF4/RF4Launcher.exe"
    if [ ! -f "$exe" ]; then
      # Установщик может положить игру в другой каталог — ищем.
      exe=$(find "${prefix}/pfx/drive_c" -maxdepth 4 -iname 'RF4Launcher.exe' 2>/dev/null | head -n1 || true)
    fi
    if [ -z "''${exe:-}" ] || [ ! -f "$exe" ]; then
      echo "RF4 не установлена в ${prefix}" >&2
      echo "Сначала: rf4-install" >&2
      exit 1
    fi

    exec ${gamescope} \
      -w 1600 -h 900 \
      -W 2240 -H 960 \
      -r 120 \
      -S fit \
      -f \
      --force-grab-cursor \
      --mangoapp \
      -- ${umu} "$exe"
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
    rf4-install
  ];

  xdg.enable = true;

  xdg.desktopEntries.rf4 = {
    name = "Russian Fishing 4";
    comment = "Russian Fishing 4 (сайтовая версия) через umu + GE-Proton";
    exec = "rf4";
    icon = "applications-games";
    terminal = false;
    categories = [ "Game" ];
    type = "Application";
  };
}
