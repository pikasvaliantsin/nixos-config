{
  lib,
  stdenvNoCC,
  makeWrapper,
  quickshell,
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
  power-profiles-daemon,
  upower,
  libnotify,
  curl,
  wl-clipboard,
  grim,
  slurp,
  satty,
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
    power-profiles-daemon
    upower
    libnotify
    curl
    wl-clipboard
    grim
    slurp
    satty
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
      --set OMARCHY_PATH $out/share/omarchy \
      --set OMARCHY_SESSION_ID niri
  '';

  meta = {
    description = "Omarchy Quickshell desktop (Niri port base)";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
