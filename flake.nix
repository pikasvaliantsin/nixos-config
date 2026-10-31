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

    nix-flatpak.url = "github:gmodena/nix-flatpak";
    nixvim.url = "github:nix-community/nixvim";
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
              backupFileExtension = "backup";
              extraSpecialArgs = { inherit inputs; };
              users.valen.imports = [ ./home-manager/home.nix ];
            };
          }
        ];
      };
    };
}
