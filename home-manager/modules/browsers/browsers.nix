# Браузеры: Firefox с декларативными настройками и Zen с кодеками.
{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:

let
  # Canonical user.js для всех Gecko-браузеров (Firefox + Zen).
  firefoxUserJs = pkgs.writeText "user.js" ''
    // === DRM / Widevine EME (принудительно включаем) ===
    pref("media.eme.enabled", true);
    pref("media.eme.activated", true);
    pref("media.gmp-widevinecdm.visible", true);
    pref("media.gmp-manager.updateEnabled", true);

    // === Аппаратное декодирование ===
    pref("media.gpu-process-decoder.enabled", true);
    pref("media.hardware-video-decoding-vulkan.enabled", true);
    pref("media.vaapi.force-enabled", true);
    pref("media.libavutil.enable-gl", true);

    // === Кодеки: старый FF-декодер ломает AAC/HEVC на NixOS ===
    pref("media.ffvpx.enabled", false);
    pref("media.libavcodec.allow-obsolete", true);

    // === Приватность ===
    pref("media.webspeech.recognition.enable", false);
    pref("browser.safebrowsing.downloads.remote.enabled", false);
    pref("browser.safebrowsing.phishing.enabled", false);
  '';

  # Отдельный профиль для YouTube-приложения: свои cookies/кэш,
  # без доступа к системному keyring (там нет паролей, только YouTube-сессия).
  youtubeArgs = [
    "--app=https://www.youtube.com"
    "--user-data-dir=${config.home.homeDirectory}/.local/share/youtube-chromium"
    "--password-store=basic"
    "--start-maximized"
    "--no-first-run"
    "--no-default-browser-check"
    "--disable-background-networking"
    "--disable-component-update"
    "--disable-domain-reliability"
    "--disable-sync"
    "--disable-breakpad"
    "--disable-crash-reporter"
    "--metrics-recording-only"
    "--disable-features=Translate,OptimizationHints,MediaRouter"
    "--ozone-platform-hint=wayland"
  ];
in
{
  home = {
    packages = [
      pkgs.thunderbird
      (
        let
          zenPkg = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default;
        in
        pkgs.symlinkJoin {
          name = "zen-browser-patched";
          paths = [ zenPkg ];
          buildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/zen \
              --prefix LD_LIBRARY_PATH : "${
                pkgs.lib.makeLibraryPath [
                  pkgs.ffmpeg
                  pkgs.gst_all_1.gst-plugins-good
                  pkgs.gst_all_1.gst-plugins-bad
                  pkgs.gst_all_1.gst-plugins-ugly
                  pkgs.gst_all_1.gst-libav
                ]
              }"
          '';
        }
      )

      (pkgs.makeDesktopItem {
        name = "youtube-stream-chromium";
        desktopName = "YouTube Stream (Chromium)";
        exec = "${pkgs.chromium}/bin/chromium ${lib.concatStringsSep " " youtubeArgs}";
        icon = "youtube-vision";
        categories = [
          "AudioVideo"
          "Network"
        ];
      })

      # Библиотеки декодинга для браузера (AAC, HEVC, H.264 SW)
      pkgs.gst_all_1.gst-plugins-good
      pkgs.gst_all_1.gst-plugins-bad
      pkgs.gst_all_1.gst-plugins-ugly
      pkgs.gst_all_1.gst-libav
      pkgs.libvpx
      pkgs.libwebp
    ];

    # Activation script: копирует canonical user.js во все .default*-профили Mozilla-браузеров.
    # Программы Gecko ищут user.js внутри директории профилей, поэтому нужно писать прямо туда.
    activation.copyUserJsToProfiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      USERJS=${lib.escapeShellArg "${firefoxUserJs}"}

      # Копируем в профили Firefox через общую директорию ~/.mozilla/firefox/
      for dir in "$HOME"/.mozilla/firefox/* ; do
        case "$dir" in
          *".default-"*|*".default")
            [ -d "$dir" ] || continue
            cp --no-preserve=mode,ownership "$USERJS" "$dir/user.js"
            ;;
        esac
      done

      # Профили Zen находятся в ~/.config/zen/<hash>.Default Profile/
      # Находим каталог с ".Default Profile" или ".default" паттерном
      zen_dir=$(find "$HOME"/.config/zen -maxdepth 1 -mindepth 1 -type d -name "*.Default*" 2>/dev/null | head -n1)
      if [ -n "$zen_dir" ]; then
        cp --no-preserve=mode,ownership "$USERJS" "$zen_dir/user.js"
      fi
    '';

    # Wayland интеграция
    sessionVariables = {
      MOZ_ENABLE_WAYLAND = "1";
      MOZ_USE_INPUT_PROTOCOL = "wayland";
    };
  };

  # Firefox через programs.firefox — declarative about:config + создаёт .mozilla/firefox/<profile>/
  programs.firefox = {
    enable = true;
    policies = {
      DisableTelemetry = true;
      EnableTrackingProtection = {
        value = true;
        encryptedPagesOnly = true;
      };
    };
    profiles.default = {
      isDefault = true;
      settings = {
        "media.eme.enabled" = true;
        "media.eme.activated" = true;
        "media.gpu-process-decoder.enabled" = true;
        "media.hardware-video-decoding-vulkan.enabled" = true;
        "media.vaapi.force-enabled" = true;
        "media.ffvpx.enabled" = false;
        "media.libavutil.enable-gl" = true;
        "browser.safebrowsing.downloads.remote.enabled" = false;
        "browser.safebrowsing.phishing.enabled" = false;
      };
    };
  };
}
