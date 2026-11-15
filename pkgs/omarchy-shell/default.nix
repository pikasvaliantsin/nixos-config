{
  lib,
  stdenvNoCC,
  makeWrapper,
  quickshell,
  qt6,
  bash,
  coreutils,
  python3,
  fontconfig,
  jq,
  gawk,
  gnugrep,
  findutils,
  procps,
  util-linux,
  iproute2,
  iputils,
  iw,
  networkmanager,
  bluez,
  upower,
  libnotify,
  curl,
  wl-clipboard,
  grim,
  slurp,
  satty,
  wl-screenrec,
  wf-recorder,
  pipewire,
  wireplumber,
  pulseaudio,
  glib,
  gtk3,
  gum,
  file,
  desktop-file-utils,
  brightnessctl,
  ddcutil,
  systemd,
  wlsunset,
  foot,
  niri,
}:

let
  runtimeDeps = [
    bash
    coreutils
    python3
    fontconfig
    jq
    gawk
    gnugrep
    findutils
    procps
    util-linux
    iproute2
    iputils
    iw
    networkmanager
    bluez
    upower
    libnotify
    curl
    wl-clipboard
    grim
    slurp
    satty
    wl-screenrec
    wf-recorder
    pipewire
    wireplumber
    pulseaudio
    glib
    gtk3
    gum
    file
    desktop-file-utils
    brightnessctl
    ddcutil
    systemd
    wlsunset
    foot
    niri
    quickshell
  ];
in
stdenvNoCC.mkDerivation {
  pname = "omarchy-shell";
  version = "4.5.0-niri";

  src = ../../vendor/omarchy-shell;

  nativeBuildInputs = [
    makeWrapper
    python3
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/omarchy $out/bin
    cp -a shell config default bin LICENSE $out/share/omarchy/
    chmod +x $out/share/omarchy/bin/*
    patchShebangs $out/share/omarchy/bin
    # Niri keybindings run these from the session PATH, not from the shell's
    # wrapped environment. Expose the compatible helpers in $out/bin too.
    for helper in $out/share/omarchy/bin/*; do
      ln -s "$helper" "$out/bin/$(basename "$helper")"
    done

    cat > $out/bin/omarchy-launch-shell <<'EOF'
#!/bin/sh
exec quickshell -p "$OMARCHY_PATH/shell"
EOF
    chmod +x $out/bin/omarchy-launch-shell

    runHook postInstall
  '';

  postFixup = ''
    wrapProgram $out/bin/omarchy-launch-shell \
      --prefix PATH : $out/share/omarchy/bin \
      --prefix PATH : ${lib.makeBinPath runtimeDeps} \
      --prefix QT_PLUGIN_PATH : ${qt6.qtimageformats}/lib/qt-6/plugins \
      --set OMARCHY_PATH $out/share/omarchy \
      --set OMARCHY_SESSION_ID niri
  '';

  meta = {
    description = "Omarchy Quickshell desktop (Niri port base)";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
