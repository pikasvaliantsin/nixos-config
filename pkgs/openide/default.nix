# OpenIDE — IDE на платформе IntelliJ IDEA (https://openide.ru).
#
# Пакет собирается из официального Linux-дистрибутива (tar.gz) с сохранением
# вендорского JetBrains Runtime: он собран Axiom JSC и совпадает по версии
# JCEF с плагином jcef-plugin, поэтому подменять его на pkgs.jetbrains.jdk
# не стоит. Все ELF-файлы дистрибутива (включая jbr и libcef.so) чинит
# autoPatchelfHook.
{
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  autoPatchelfHook,
  cairo,
  coreutils,
  cups,
  dbus,
  e2fsprogs,
  fetchurl,
  fontconfig,
  git,
  glibcLocales,
  gnugrep,
  lib,
  libGL,
  libgbm,
  libnotify,
  libsecret,
  libx11,
  libxcb,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxinerama,
  libxkbcommon,
  libxrandr,
  libxrender,
  libxtst,
  libxxf86vm,
  makeDesktopItem,
  makeWrapper,
  nspr,
  nss,
  pango,
  patchelf,
  python3,
  stdenv,
  udev,
  unzip,
  wayland,
  which,
  zlib,
}:

let
  inherit (stdenv.hostPlatform) system;

  version = "2026.2.3";
  buildNumber = "262.10968.63.2";

  sources = {
    x86_64-linux = {
      url = "https://download.openide.ru/${buildNumber}/openIDE-${buildNumber}.tar.gz";
      hash = "sha256-6B9Y4v8mC3uad4Sm6xelO2jF51vS/WjlrZ9QDl8J+JQ=";
    };
    aarch64-linux = {
      url = "https://download.openide.ru/${buildNumber}/openIDE-${buildNumber}-aarch64.tar.gz";
      hash = "sha256-4v/U83Qvi1xodILU77cbJPfIkXDB6nzuKLYnk+LLbR4=";
    };
  };

  source = sources.${system} or (throw "OpenIDE: платформа ${system} не поддерживается");

  # Библиотеки, которые IDE грузит через JNA по имени, а не линкует при сборке.
  jnaLibs = [
    e2fsprogs
    libnotify
    libsecret
    udev
  ];

  desktopItem = makeDesktopItem {
    name = "openide";
    exec = "openide %f";
    icon = "openide";
    desktopName = "OpenIDE";
    genericName = "Среда разработки";
    comment = "IDE на платформе IntelliJ IDEA";
    categories = [
      "Development"
      "IDE"
    ];
    startupNotify = true;
    startupWMClass = "openide";
  };
in
stdenv.mkDerivation {
  pname = "openide";
  inherit version;

  src = fetchurl source;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    patchelf
    unzip
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    fontconfig
    libGL
    libgbm
    libx11
    libxcb
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxinerama
    libxkbcommon
    libxrandr
    libxrender
    libxtst
    libxxf86vm
    nspr
    nss
    pango
    stdenv.cc.cc.lib
    udev
    wayland
    zlib
  ];

  runtimeDependencies = jnaLibs ++ [ fontconfig ];

  dontConfigure = true;
  dontBuild = true;
  # Стрип 1,3 ГБ библиотек ничего не даёт, но заметно замедляет сборку.
  dontStrip = true;

  postPatch = ''
    # autoPatchelfHook разворачивает "." из RPATH относительно build-каталога
    # и начинает предпочитать вендорные копии библиотек. У libjcef.so как раз
    # такой RPATH — фиксируем его на каталог плагина.
    patchelf --set-rpath '$ORIGIN' plugins/jcef-plugin/jcef/libjcef.so

    # JNA ищет нативные библиотеки по имени, поэтому пути к ним передаём
    # через vmoptions (так же делает nixpkgs для JetBrains IDE).
    echo "-Djna.library.path=${lib.makeLibraryPath jnaLibs}" >> bin/openide64.vmoptions
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p \
      $out/bin \
      $out/$pname \
      $out/share/applications \
      $out/share/icons/hicolor/scalable/apps \
      $out/share/icons/hicolor/128x128/apps

    cp -a . $out/$pname

    ln -s $out/$pname/bin/openide.png $out/share/icons/hicolor/128x128/apps/$pname.png
    ln -s $out/$pname/bin/openide.svg $out/share/icons/hicolor/scalable/apps/$pname.svg

    for launcher in openide openide.sh; do
      wrapProgram "$out/$pname/bin/$launcher" \
        --prefix PATH : ${
          lib.makeBinPath [
            coreutils
            git
            gnugrep
            which
          ]
        } \
        --suffix PATH : ${lib.makeBinPath [ python3 ]} \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ fontconfig ]} \
        --set-default LOCALE_ARCHIVE ${glibcLocales}/lib/locale/locale-archive \
        --set-default OPENIDE_JDK "$out/$pname/jbr"
    done

    ln -s "$out/$pname/bin/openide" $out/bin/openide
    ln -s ${desktopItem}/share/applications/openide.desktop $out/share/applications/openide.desktop

    runHook postInstall
  '';

  meta = {
    homepage = "https://openide.ru/";
    description = "IDE на платформе IntelliJ IDEA с открытым исходным кодом";
    longDescription = ''
      OpenIDE — мультиязычная среда разработки для Java, Kotlin, Python, Go,
      PHP и JavaScript/TypeScript, основанная на IntelliJ IDEA Platform.
      Включает собственный маркетплейс плагинов и не зависит от сервисов
      JetBrains.
    '';
    license = lib.licenses.agpl3Only;
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
    platforms = builtins.attrNames sources;
    mainProgram = "openide";
  };
}
