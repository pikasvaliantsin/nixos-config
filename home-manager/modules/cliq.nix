{ config, pkgs, ... }:

let
  cliqEnv = pkgs.buildFHSUserEnv {
    name = "zoho-cliq";
    targetPkgs = pkgs: with pkgs; [
      # Базовые библиотеки, необходимые Cliq
      nspr
      nss
      gtk3
      glib
      libX11
      libxkbcommon
      xorg.libXScrnSaver
      xorg.libXcomposite
      xorg.libXdamage
      xorg.libXext
      xorg.libXfixes
      xorg.libXi
      xorg.libXrandr
      xorg.libxcb
      zlib
      stdenv.cc.cc.lib
      # Дополнительно для звука и сети (если нужно)
      alsa-lib
      libpulseaudio
    ];
    runScript = "${pkgs.steam-run}/bin/steam-run /home/valen/Downloads/cliq-extract/opt/Cliq/cliq";
  };
in {
  environment.systemPackages = [ cliqEnv ];
}
