# Оверлеи хоста. Подключаются в system/nix.nix.
_final: prev: {
  # Согласование steam-run с рантаймом системного Steam.
  steam-run =
    (prev.steam.override {
      extraPkgs = import ./steam-extra-pkgs.nix;
    }).run;

  # Совместимость со старым именем пакета.
  minizip-ng-compat = prev.minizip-ng;

  # Обход отсутствующей man-страницы: иначе сборка падает на installCheck.
  khal = prev.khal.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      mkdir -p $man/share/man/man1
      touch $man/share/man/man1/khal.1
    '';
  });
}
