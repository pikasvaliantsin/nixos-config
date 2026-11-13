{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule {
  pname = "omarchy-speedtest";
  version = "unstable-2026-11-02";

  src = fetchFromGitHub {
    owner = "omacom";
    repo = "omarchy-speedtest";
    rev = "66050b5baed173156b333ee88b21f3856f5612ca";
    hash = "sha256-Mt9y5MNu2/iAcBFg4c2skIHw2cXaT63SsncN3+Q6kZ8=";
  };

  vendorHash = null;
  doCheck = false;
  ldflags = [ "-s" "-w" ];

  meta = {
    description = "Omarchy network speed test client";
    license = lib.licenses.mit;
    mainProgram = "omarchy-speedtest";
    platforms = lib.platforms.linux;
  };
}
