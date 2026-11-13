# Декларативные web-приложения (аналог omarchy-webapp-install).
#
# Web app в Omarchy — это не Electron: .desktop-файл, который запускает
# Chromium-based браузер с --app=<url>, плюс иконка в hicolor-теме и
# StartupWMClass, чтобы док и заголовок окна брали имя из лаунчера, а не из
# заголовка страницы. Здесь то же самое, но из конфига:
#
#   mySystem.webapps.entries.maps = {
#     name = "Google Maps";
#     url = "https://maps.google.com";
#     iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/google-maps.png";
#   };
#
# Иконку можно не указывать: подберётся apple-touch-icon сайта, затем favicon
# Google, затем /favicon.ico. Короткая форма — имя равно ключу:
#
#   mySystem.webapps.entries."Google Maps" = "https://maps.google.com";
#
# Иконку можно закрепить в сторе (и тогда её не нужно тянуть при активации),
# указав хеш:
#
#   iconUrl = "https://…/icon.png";
#   iconHash = "sha256-…";   # nix-prefetch-url --type sha256 <url>
#
# Записи можно вести и из TUI `webapps` (webapps-tui.nix): он пишет
# webapps.json рядом с этим файлом. Одноимённые записи из Nix главнее JSON.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.mySystem.webapps;

  iconDirRelative = ".local/share/icons/hicolor/256x256/apps";
  iconDir = "${config.home.homeDirectory}/${iconDirRelative}";

  # ---------------------------------------------------------------------------
  # Строковые утилиты (порт логики omarchy-webapp-window-class и -install)
  # ---------------------------------------------------------------------------

  # Имя файла: hicolor допускает [a-z0-9-_.], поэтому всё остальное — в "-".
  slugify =
    s:
    lib.concatMapStrings (c: if builtins.match "[a-z0-9]" c != null then c else "-") (
      lib.stringToCharacters (lib.toLower s)
    );

  # Разбор URL без регулярок на стороне shell: scheme://authority/path...
  urlParts =
    url:
    let
      m = builtins.match "([a-zA-Z][a-zA-Z0-9+.-]*)://([^/?#]+)(.*)" url;
    in
    if m == null then
      {
        scheme = "https";
        authority = "";
        path = "";
      }
    else
      {
        scheme = builtins.elemAt m 0;
        authority = builtins.elemAt m 1;
        path = builtins.elemAt m 2;
      };

  hostOf =
    url:
    let
      # userinfo@host:port → host; для IPv6 в скобках это вырождается,
      # но такие URL в web app всё равно не нужны.
      noUser = lib.last (lib.splitString "@" (urlParts url).authority);
    in
    lib.head (lib.splitString ":" noUser);

  # Chromium на Wayland называет окно --app по хосту и пути URL:
  #   https://open.spotify.com/ -> chrome-open.spotify.com__-Default
  #   https://app.hey.com        -> chrome-app.hey.com_-Default
  # Это же значение уходит в StartupWMClass и становится именем .desktop,
  # чтобы доки, ищущие лаунчер по app-id, его находили.
  windowClass =
    url:
    let
      path = (urlParts url).path;
      cleanPath = lib.head (lib.splitString "#" (lib.head (lib.splitString "?" path)));
    in
    "chrome-${lib.toLower (hostOf url)}_${
      lib.replaceStrings [ "/" ] [ "_" ] (if cleanPath == "" then "/" else cleanPath)
    }-Default";

  # Значение .desktop-файла по Desktop Entry Spec: экранируем обратный слэш
  # первым, затем управляющие символы. Иначе перевод строки в имени создаст
  # второй ключ и подменит, например, Exec.
  desktopString =
    s:
    lib.replaceStrings [ "\t" "\r" "\n" ] [ "\\t" "\\r" "\\n" ] (
      lib.replaceStrings [ "\\" ] [ "\\\\" ] s
    );

  # Один аргумент Exec: в двойных кавычках \ ` $ " экранируются, % удваивается.
  execArg =
    s: "\"${lib.replaceStrings [ "\\" "`" "$" "\"" "%" ] [ "\\\\" "\\`" "\\$" "\\\"" "%%" ] s}\"";
  # Общий тип записи: один и тот же для Nix-записей и для JSON, который пишет TUI.
  entryType = lib.types.submodule (
    { name, ... }:
    {
      options = {
        name = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "Имя в лаунчере и заголовке окна.";
        };

        url = lib.mkOption {
          type = lib.types.str;
          description = "http(s)-URL приложения.";
        };

        comment = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Comment в .desktop; по умолчанию совпадает с name.";
        };

        icon = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = ''
            Готовая иконка (файл или деривация, например pkgs.fetchurl).
            Приоритетнее iconUrl.
          '';
        };

        iconUrl = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            URL иконки. С iconHash скачивается в стор при сборке, без
            него — при активации (нужна сеть, повторно не качается).
            Если не задано ни icon, ни iconUrl, иконка подбирается
            автоматически: apple-touch-icon сайта → favicon Google →
            /favicon.ico.
          '';
        };

        iconHash = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "SRI-хеш для iconUrl: фиксирует иконку в сторе.";
        };

        iconExt = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Расширение файла иконки; по умолчанию из имени файла или png.";
        };

        extraArgs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Дополнительные флаги Chromium: профиль, --start-maximized, …";
        };

        isolatedProfile = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Отдельный профиль Chromium в ~/.local/share/webapps/<имя>:
            свои cookies и кэш, не видно сессий основного браузера.
          '';
        };

        profileDir = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Явный --user-data-dir (абсолютный или от $HOME).";
        };

        categories = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "Network" ];
          description = "Categories в .desktop.";
        };

        mimeTypes = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "MimeType, например [ \"x-scheme-handler/mailto\" ].";
        };

        terminal = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Terminal=true (web app'ам не нужно).";
        };

        wmClass = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Переопределить StartupWMClass, если Chromium назвал окно иначе.";
        };

        desktopFileName = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Переопределить имя .desktop (по умолчанию — window class).";
        };

        extraDesktop = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "Произвольные ключи .desktop, например NoDisplay = \"true\".";
        };
      };
    }
  );

  entryValueType = lib.types.coercedTo lib.types.str (url: { inherit url; }) entryType;

  # Записи из JSON (их ведёт TUI `webapps`). Прогоняем через тот же тип,
  # чтобы работали значения по умолчанию и проверка опечаток. Читаем
  # относительно модуля — так работает pure eval.
  jsonEntries =
    if !(builtins.pathExists ./webapps.json) then
      { }
    else
      (lib.evalModules {
        modules = [
          {
            options.entries = lib.mkOption {
              type = lib.types.attrsOf entryValueType;
              default = { };
            };
            config.entries = builtins.fromJSON (builtins.readFile ./webapps.json);
          }
        ];
      }).config.entries;

  # Nix-записи главнее одноимённых JSON-записей.
  allEntries = jsonEntries // cfg.entries;

in
{
  options.mySystem.webapps = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = allEntries != { };
      defaultText = lib.literalExpression "entries != { }";
      description = "Включить декларативные web-приложения.";
    };

    browser = lib.mkOption {
      type = lib.types.package;
      default = pkgs.chromium;
      defaultText = lib.literalExpression "pkgs.chromium";
      description = ''
        Chromium-based браузер: web app открывается его флагом --app.
        Firefox/Zen не подходят — у них такого режима нет.
      '';
    };

    binary = lib.mkOption {
      type = lib.types.str;
      default = cfg.browser.meta.mainProgram or (lib.getName cfg.browser);
      defaultText = lib.literalExpression "browser.meta.mainProgram";
      description = "Имя исполняемого файла внутри browser (chromium, brave, …).";
    };

    defaultArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "--ozone-platform-hint=wayland"
        "--no-first-run"
        "--no-default-browser-check"
      ];
      description = "Флаги Chromium, общие для всех web app.";
    };

    entries = lib.mkOption {
      type = lib.types.attrsOf entryValueType;
      default = { };
      description = "Web app'ы: атрибут — ключ, значение — URL (кратко) или набор опций.";
    };
  };

  config = lib.mkIf (cfg.enable && allEntries != { }) (
    let
      # Всё, что нужно знать про одну запись, считаем один раз.
      entries = lib.mapAttrs (
        key: e:
        let
          # Ключ, а не отображаемое имя: в имени может быть что угодно, а
          # иконка должна называться предсказуемо.
          slug = slugify key;
          iconName = "webapp-${slug}";
          wmClass = if e.wmClass != null then e.wmClass else windowClass e.url;

          profile =
            if e.profileDir != null then
              (
                if lib.hasPrefix "/" e.profileDir then
                  e.profileDir
                else
                  "${config.home.homeDirectory}/${e.profileDir}"
              )
            else if e.isolatedProfile then
              "${config.home.homeDirectory}/.local/share/webapps/${slug}"
            else
              null;

          args = [
            "--app=${e.url}"
          ]
          ++ lib.optional (profile != null) "--user-data-dir=${profile}"
          ++ cfg.defaultArgs
          ++ e.extraArgs;

          exec = lib.concatStringsSep " " (
            [ (execArg "${cfg.browser}/bin/${cfg.binary}") ] ++ map execArg args
          );

          # Иконка: файл из стора / fetchurl с хешем → home.file;
          # иначе URL (в т.ч. favicon сайта) → скачивание при активации.
          iconFromStore =
            if e.icon != null then
              e.icon
            else if e.iconUrl != null && e.iconHash != null then
              pkgs.fetchurl {
                url = e.iconUrl;
                hash = e.iconHash;
              }
            else
              null;

          # Цепочка иконок: явная → стандартные пути сайта → favicon.
          # Порядок = качество: apple-touch-icon обычно 180px+, favicon.ico 32px.
          origin = "${(urlParts e.url).scheme}://${(urlParts e.url).authority}";
          faviconUrl = "https://www.google.com/s2/favicons?domain=${hostOf e.url}&sz=256";
          iconChain =
            if e.icon != null || (e.iconUrl != null && e.iconHash != null) then
              [ ]
            else
              lib.optional (e.iconUrl != null) e.iconUrl
              ++ [
                "${origin}/apple-touch-icon.png"
                faviconUrl
                "${origin}/favicon.ico"
              ];

          ext =
            if e.iconExt != null then
              e.iconExt
            else if e.icon != null then
              (
                let
                  m = builtins.match ".*\\.([A-Za-z0-9]+)" (toString e.icon);
                in
                if m == null then "png" else lib.toLower (builtins.head m)
              )
            else
              "png";

          # Файлы иконки: под своим именем (Icon=) и под именем app-id —
          # часть доков (DMS в том числе) ищет иконку именно по нему.
          iconFiles = lib.optionalAttrs (iconFromStore != null) {
            "${iconDirRelative}/${iconName}.${ext}".source = iconFromStore;
            "${iconDirRelative}/${wmClass}.${ext}".source = iconFromStore;
          };

          desktopText =
            lib.concatStringsSep "\n" (
              [
                "[Desktop Entry]"
                "Version=1.0"
                "Type=Application"
                "Name=${desktopString e.name}"
                "Comment=${desktopString (if e.comment != "" then e.comment else e.name)}"
                "Exec=${desktopString exec}"
                "Icon=${desktopString iconName}"
                "Terminal=${if e.terminal then "true" else "false"}"
                "StartupNotify=true"
                "StartupWMClass=${desktopString wmClass}"
                "Categories=${lib.concatStringsSep ";" e.categories};"
              ]
              ++ lib.optional (e.mimeTypes != [ ]) "MimeType=${lib.concatStringsSep ";" e.mimeTypes};"
              ++ lib.mapAttrsToList (k: v: "${k}=${desktopString v}") e.extraDesktop
            )
            + "\n";
        in
        {
          desktopFileName = if e.desktopFileName != null then e.desktopFileName else wmClass;
          inherit desktopText iconFiles;
          download =
            if iconChain == [ ] then
              null
            else
              {
                urls = iconChain;
                inherit slug ext wmClass;
              };
        }
      ) allEntries;

      downloads = lib.filter (d: d != null) (lib.attrValues (lib.mapAttrs (_: v: v.download) entries));

      iconScript = ''
        icons="${iconDir}"
        ${pkgs.coreutils}/bin/mkdir -p "$icons"

        # Иконка качается только когда набор URL сменился или файл пропал:
        # switch без сети не ломается, прежняя иконка остаётся на месте.
        fetch_icon() {
          icon=$1 appid_icon=$2 stamp=$3
          shift 3
          chain=$(printf '%s\n' "$@")
          if [ -s "$icon" ] && [ "$(${pkgs.coreutils}/bin/cat "$stamp" 2>/dev/null)" = "$chain" ]; then
            return 0
          fi
          tmp="$stamp.tmp"
          for url in "$@"; do
            if ${pkgs.curl}/bin/curl -fsSL --retry 2 --max-time 20 -o "$tmp" "$url" 2>/dev/null && [ -s "$tmp" ]; then
              ${pkgs.coreutils}/bin/install -m 644 "$tmp" "$icon"
              ${pkgs.coreutils}/bin/install -m 644 "$tmp" "$appid_icon"
              printf '%s' "$chain" > "$stamp"
              ${pkgs.coreutils}/bin/rm -f "$tmp"
              return 0
            fi
          done
          echo "webapps: не удалось скачать иконку для $icon (оставляю прежнюю)" >&2
          ${pkgs.coreutils}/bin/rm -f "$tmp"
        }

        ${lib.concatStringsSep "\n" (
          map (
            d:
            ''fetch_icon "$icons/webapp-${d.slug}.${d.ext}" "$icons/${d.wmClass}.${d.ext}" "$icons/.webapp-${d.slug}.url" ${
              lib.concatMapStrings (u: " ${lib.escapeShellArg u}") d.urls
            }''
          ) downloads
        )}
      '';
    in
    {
      assertions = lib.mapAttrsToList (key: e: {
        assertion = builtins.match "https?://[^[:space:]]+" e.url != null;
        message = "mySystem.webapps.entries.${key}: URL должен быть http(s) и без пробелов.";
      }) allEntries;

      xdg.dataFile = lib.mapAttrs' (
        _: v: lib.nameValuePair "applications/${v.desktopFileName}.desktop" { text = v.desktopText; }
      ) entries;

      home.file = lib.foldl' (acc: v: acc // v.iconFiles) { } (lib.attrValues entries);

      home.activation.webappIcons = lib.mkIf (downloads != [ ]) (
        lib.hm.dag.entryAfter [ "writeBoundary" ] iconScript
      );
    }
  );
}
