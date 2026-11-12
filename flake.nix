{
  description = "NixOS конфигурация ASUS ExpertBook (Niri + DMS)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dms.url = "github:duxlabs-dev/dux-shell";
    dux-gop.url = "github:duxlabs-dev/dux-gop";
    dank-greeter.url = "github:duxlabs-dev/dux-greeter";
    dux-calendar.url = "github:duxlabs-dev/dux-calendar";
    dux-search.url = "github:duxlabs-dev/dux-search";
    dux-files.url = "github:duxlabs-dev/dux-files";

    zen-browser = {
      url = "github:youwen5/zen-browser-flake/pull/23/head";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ayugram-desktop.url = "github:ndfined-crp/ayugram-desktop";
    # Нужен напрямую, чтобы пересобрать tg_owt против ffmpeg_6 (ABI).
    tg_owt.url = "github:ndfined-crp/tg_owt";

    nixvim.url = "github:nix-community/nixvim";

    # niri-git: в nixpkgs только стабильный niri, свежий — в niri-flake.
    # Без follows: niri-unstable требует пакеты, которых уже нет в нашем
    # nixpkgs (libdisplay-info_0_2), поэтому собирается со своим пином.
    niri.url = "github:sodiboo/niri-flake";
    disko.url = "github:nix-community/disko";
    pyroclear.url = "github:shreyanth-sureshkrishnaa/pyroclear";
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      disko,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      formatter.${system} = pkgs.nixfmt;

      packages.${system} = {
        openide = pkgs.callPackage ./pkgs/openide { };
        ayugram-ffmpeg6 = pkgs.callPackage ./pkgs/ayugram-ffmpeg6 { inherit inputs; };

        # Атрибуты для ночного билдера на VPS (nixos-servers/modules/nix-cache.nix):
        # он собирает их на сервере, Harmonia отдаёт ноуту уже готовое.
        # zen-browser и openide сюда не входят: первый слишком тяжёл для 8 ГБ,
        # второй обновляется вручную.
        cache-dms = inputs.dms.packages.${system}.default;
        cache-dux-files = inputs.dux-files.packages.${system}.default;
        cache-dux-gop = inputs.dux-gop.packages.${system}.default;
        cache-dux-search = inputs.dux-search.packages.${system}.default;
        cache-dux-calendar = inputs.dux-calendar.packages.${system}.default;
        cache-dank-greeter = inputs.dank-greeter.packages.${system}.default;
        cache-ayugram = inputs.ayugram-desktop.packages.${system}.default;
        cache-niri = inputs.niri.packages.${system}.niri-unstable;
      };

      nixosConfigurations.asus-expertbook = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          disko.nixosModules.disko
          ./hosts/asus-expertbook/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              # Уникальные имена бэкапов: DMS периодически заменяет симлинки
              # обычными файлами, фиксированный .backup быстро начинает конфликтовать.
              backupCommand = pkgs.writeShellScript "hm-backup" ''
                set -euo pipefail
                target="$1"
                ${pkgs.coreutils}/bin/mv -- "$target" \
                  "$target.$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S).backup"
              '';
              extraSpecialArgs = { inherit inputs; };
              users.valen.imports = [ ./home-manager/home.nix ];
            };
          }
        ];
      };
    };
}
