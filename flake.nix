{
  description = "NixOS конфигурация с Niri + Noctalia (v5)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri = {
      url = "github:YaLTeR/niri";
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

  danksearch = {
    url = "github:AvengeMedia/danksearch";
    inputs.nixpkgs.follows = "nixpkgs";
   };
};

outputs = { self, nixpkgs, home-manager, niri, dms, ... }@inputs: {
  nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };
    modules = [
      ./hosts/desktop/configuration.nix
      home-manager.nixosModules.home-manager
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          users.valen = import ./home-manager/home.nix;
          extraSpecialArgs = {
            inherit inputs;
            unstable = import inputs.nixpkgs-unstable {
              system = "x86_64-linux";
              config.allowUnfree = true;
            };
          };
        };
      }
    ];
  };
};
}
