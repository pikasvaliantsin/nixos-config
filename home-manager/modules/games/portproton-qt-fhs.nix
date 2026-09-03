{ pkgs ? import <nixpkgs> {} }:

let
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    pyqt6
    requests
    urllib3
    certifi
    psutil
  ]);
in
pkgs.buildFHSEnv {
  name = "portproton-qt";

  targetPkgs = pkgs: with pkgs; [
    # Python & Qt
    pythonEnv

    # Системные утилиты и декомпрессоры для WINE/префиксов
    bash
    coreutils
    curl
    wget
    git
    gnupg
    which
    file
    findutils
    gawk
    util-linux
    tar
    xz
    unzip
    p7zip
    cabextract
    zsync
    bubblewrap
    attr
    acl
    libcap

    # Графика и драйверы
    vulkan-loader
    vulkan-tools
    mesa
    mesa.drivers
    libGL
    libGLU
    libva
    libvdpau

    # Звук
    alsa-lib
    libpulseaudio
    pipewire

    # X11, Wayland, шрифты и Qt QPA зависимости
    xorg.libX11
    xorg.libXcursor
    xorg.libXrandr
    xorg.libXi
    xorg.libXinerama
    xorg.libXxf86vm
    xorg.libXcomposite
    xorg.libXext
    xorg.libXrender
    xorg.libxcb
    xorg.libXfixes
    xorg.libXtst
    xorg.xcbutilwm
    xorg.xcbutilimage
    xorg.xcbutilkeysyms
    xorg.xcbutilrenderutil
    wayland
    libxkbcommon
    fontconfig
    freetype

    # Сеть, крипто и рантайм
    openssl
    gnutls
    nss
    nspr
    dbus
    zlib
    glib
  ];

  multiPkgs = pkgs: with pkgs; [
    # 32-bit библиотеки (обязательно для запуска 32-bit компонентов WINE)
    vulkan-loader
    mesa.drivers
    libGL
    alsa-lib
    libpulseaudio
    pipewire
    xorg.libX11
    xorg.libXcursor
    xorg.libXrandr
    xorg.libXi
    xorg.libXext
    xorg.libxcb
    libxkbcommon
    openssl
    gnutls
    zlib
  ];

  runScript = pkgs.writeShellScript "portproton-qt-launcher" ''
    set -e

    PORTPROTON_QT_DIR="$HOME/.local/share/PortProtonQt"

    if [ ! -d "$PORTPROTON_QT_DIR/.git" ]; then
      echo "==> Клонирование PortProtonQt в $PORTPROTON_QT_DIR..."
      mkdir -p "$PORTPROTON_QT_DIR"
      git clone --depth 1 https://github.com/Castro-Fidel/PortProtonQt.git "$PORTPROTON_QT_DIR"
    fi

    export LC_ALL="C.UTF-8"
    export LANG="C.UTF-8"

    # Приоритет XCB через Xwayland для корректной стыковки Qt и окон WINE
    if [ -n "$DISPLAY" ]; then
      export QT_QPA_PLATFORM=xcb
    fi

    cd "$PORTPROTON_QT_DIR"
    exec python3 main.py "$@"
  '';

  extraInstallCommands = ''
    mkdir -p $out/share/applications
    cat > $out/share/applications/portproton-qt.desktop <<EOF
[Desktop Entry]
Name=PortProton Qt
Comment=PortProton Qt GUI in FHS environment
Exec=portproton-qt %U
Icon=portproton
Terminal=false
Type=Application
Categories=Game;
EOF
  '';
}