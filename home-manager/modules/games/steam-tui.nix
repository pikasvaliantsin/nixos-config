# steam-tui — TUI-клиент Steam, собранный из upstream-релиза.
# Подключается через pkgs.callPackage в shell/cli.nix.
{
  lib,
  rustPlatform,
  fetchFromGitHub,
  cmake,
  perl,
  pkg-config,
  zlib,
}:

let
  version = "2.1.0";
  src = fetchFromGitHub {
    owner = "vanyapoker";
    repo = "steam-tui";
    tag = "v${version}";
    hash = "sha256-iw4yZfkCynKq2gK39w82oPbGbNC5CZRpYSHNyNW/ogY=";
  };
in
rustPlatform.buildRustPackage {
  pname = "steam-tui";
  inherit version src;

  cargoLock.lockFile = "${src}/Cargo.lock";

  doCheck = false;

  nativeBuildInputs = [
    cmake
    perl
    pkg-config
  ];

  buildInputs = [
    perl
    zlib
  ];

  meta = {
    description = "TUI Steam launcher";
    homepage = "https://github.com/vanyapoker/steam-tui";
    license = lib.licenses.mit;
    mainProgram = "steam-tui";
  };
}
