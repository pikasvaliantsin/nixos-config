# nixos-config/flake.nix
{
  description = "NixOS конфигурация Asus Expertbook (Niri + DMS)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dms = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dgop = {
      url = "github:AvengeMedia/dgop";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dank-greeter = {
      url = "github:AvengeMedia/dank-greeter";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ayugram-desktop = {
      url = "github:ndfined-crp/ayugram-desktop";
      # Если ayugram требует unstable-пакеты, перевязываем его на unstable:
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak";
    zoho-cliq.url = "github:skyd1v3r/zoho-cliq-flake";
    nixvim.url = "github:nix-community/nixvim";
    disko.url = "github:nix-community/disko";
    aurelia.url = "github:Drackrath/Aurelia";
    aurelia-tui.url = "github:skyd1v3r/aurelia-tui-flake";
    pyroclear.url = "github:shreyanth-sureshkrishnaa/pyroclear";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      disko,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      nixosConfigurations.asus-expertbook = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs unstable; };
        modules = [
          disko.nixosModules.disko
          ./hosts/asus-expertbook/disko-config.nix
          ./hosts/asus-expertbook/configuration.nix
          home-manager.nixosModules.home-manager

          # Системная настройка nixpkgs и оверлей
          {
            nixpkgs.overlays = [
              (final: prev: {
                # Если prev.minizip-ng отсутствует, берём из unstable или фоллбэчимся
                minizip-ng-compat = prev.minizip-ng or unstable.minizip-ng or prev.minizip;
              })
            ];

            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "backup";
              users.valen = import ./home-manager/home.nix;
              extraSpecialArgs = { inherit inputs unstable; };
            };
          }
        ];
      };
    };
}
