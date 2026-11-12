_:

{
  # ========================================
  # NIX / PACKAGE MANAGEMENT
  # ========================================
  nixpkgs = {
    config.allowUnfree = true;
    overlays = [ (import ./overlays.nix) ];
  };

  # Интеграция внешних бинарников (AppImage, nix-ld)
  programs.appimage.enable = true;
  programs.nix-ld.enable = true;

  # Автоочистка: раз в неделю удаляем поколения старше 14 дней.
  # Без options nix-collect-garbage чистит только мёртвые пути и не трогает
  # старые generation'ы.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    randomizedDelaySec = "45min";
    options = "--delete-older-than 14d";
  };

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
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "ayugram-desktop.cachix.org-1:AZ5EqHrJsAKL5YkZYLPEsb1FdD9QlypUwQ0REcJftgA="
    ];
  };
}
