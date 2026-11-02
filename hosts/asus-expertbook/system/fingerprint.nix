# Поддержка сканера отпечатков ELAN 04f3:0c77 (ELAN:ARM-M4).
#
# В upstream libfprint этого ID нет, но community-патчи добавляют его в
# драйвер elanmoc. Патчи написаны под libfprint 1.95.1+tod1 (Ubuntu 26.04),
# поэтому здесь собирается именно эта версия.
#
# Источник патчей: https://github.com/Alexys829/elan-0c77-libfprint
{ lib, ... }:

let
  patchDir = ./fingerprint/patches;
  series = builtins.filter (n: n != "") (
    lib.splitString "\n" (builtins.readFile (patchDir + "/series"))
  );
  patches = map (n: patchDir + "/${n}") series;
in
{
  nixpkgs.overlays = [
    (final: prev: {
      libfprint = prev.libfprint.overrideAttrs (old: {
        version = "1.95.1+tod1";
        src = prev.fetchurl {
          url = "https://archive.ubuntu.com/ubuntu/pool/main/libf/libfprint/libfprint_1.95.1+tod1.orig.tar.bz2";
          hash = "sha256-sExVzhsfC8+Xym6ePfvK2TGsLo+HwpVIyT0app2fbGA=";
        };
        patches = patches;

        # В 1.95.1 нет tests/test-runner.sh, зато есть TOD-тест со
        # шебангом /bin/bash, которого в NixOS нет.
        postPatch = ''
          patchShebangs \
            libfprint/tod/tests/check-library-symbols.sh \
            tests/unittest_inspector.py \
            tests/virtual-image.py \
            tests/umockdev-test.py \
            tests/test-generated-hwdb.sh
        '';

        # Тест udev-hwdb падает и в upstream-сборке (известная проблема,
        # о ней пишет и автор патчей) — исключаем только его группу.
        installCheckPhase = ''
          runHook preInstallCheck
          meson test --no-rebuild --print-errorlogs --no-suite data
          runHook postInstallCheck
        '';
      });
    })
  ];

  services.fprintd.enable = true;
}
