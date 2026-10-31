{
  config,
  lib,
  pkgs,
  ...
}:

{
  # ========================================
  # NIX / PACKAGE MANAGEMENT
  # ========================================
  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [ (import ./overlays.nix) ];

  # Интеграция внешних бинарников (AppImage, nix-ld)
  programs.appimage.enable = true;
  programs.nix-ld.enable = true;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    max-jobs = "auto";
    trusted-users = [
      "root"
      "@wheel"
    ];
    substituters = [
      "https://cache.nixos.org"
      "https://ayugram-desktop.cachix.org"
      "https://tg-owt.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "ayugram-desktop.cachix.org-1:AZ5EqHrJsAKL5YkZYLPEsb1FdD9QlypUwQ0REcJftgA="
      "tg-owt.cachix.org-1:lp0BukIhSK3EIyLcDhDZ5zABgT48nmNp6t4SnZ0wr8w="
    ];
  };
}
