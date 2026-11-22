{
  description = "NixOS конфигурация ASUS ExpertBook (Niri + DMS)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # DUX — только стабильный канал: master у апстрима нестабилен.
    dux-gop.url = "github:duxlabs-dev/dux-gop/stable-2.1";
    dank-greeter.url = "github:duxlabs-dev/dux-greeter/stable-2.1";
    dux-calendar.url = "github:duxlabs-dev/dux-calendar/stable-2.1";
    dux-search.url = "github:duxlabs-dev/dux-search/stable-2.1";
    dux-files.url = "github:duxlabs-dev/dux-files/stable-2.1";

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
    # Niri main: press/release binds and the GlobalShortcuts portal landed
    # after 26.04. Used only for programs.niri.package.
    niri-git.url = "github:niri-wm/niri";
    # Superwhisper Linux: official flake with a Home Manager module. The
    # package carries its own nixpkgs with an allowUnfree predicate.
    superwhisper.url = "github:superultrainc/superwhisper-linux-releases";
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
        # disko из flake.lock (тот же input, что и nixosModules.disko).
        # Запуск: nix run .#disko -- --mode ... --flake .#host
        disko = disko.packages.${system}.disko;

        openide = pkgs.callPackage ./pkgs/openide { };
        ayugram-ffmpeg6 = pkgs.callPackage ./pkgs/ayugram-ffmpeg6 { inherit inputs; };
        omarchy-shell = pkgs.callPackage ./pkgs/omarchy-shell { };
        omarchy-speedtest = pkgs.callPackage ./pkgs/omarchy-speedtest { };

        # Атрибуты для ночного билдера на VPS (nixos-servers/modules/nix-cache.nix):
        # он собирает их на сервере, Harmonia отдаёт ноуту уже готовое.
        # zen-browser и openide сюда не входят: первый слишком тяжёл для 8 ГБ,
        # второй обновляется вручную.
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

      # Тестовая установка рядом с CachyOS: тот же конфиг, но disko
      # форматирует только RF4TEST-ROOT / RF4TEST-ESP (см. hosts/gaming-test).
      nixosConfigurations.gaming-test = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          disko.nixosModules.disko
          ./hosts/gaming-test/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupCommand = pkgs.writeShellScript "hm-backup" ''
                set -euo pipefail
                target="$1"
                ${pkgs.coreutils}/bin/mv -- "$target" \
                  "$target.$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S).backup"
              '';
              extraSpecialArgs = { inherit inputs; };
              # Минимальный home только для теста: без nixvim/superwhisper/
              # dux/Omarchy/FS25 и прочих пользовательских модулей.
              users.valen.imports = [ ./hosts/gaming-test/home.nix ];
            };
          }
        ];
      };
    };
}
