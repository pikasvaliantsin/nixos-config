# Общий список библиотек для FHS-окружений Steam и steam-run.
# Используется и в programs.steam, и в оверлее steam-run (overlays.nix).
pkgs: with pkgs; [
  vulkan-loader
  vulkan-tools
  fontconfig
  freetype
  libxkbcommon
  gnutls
  openssl
  nss
  nspr
  dbus
  zlib
]
