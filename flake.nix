{
  description = "Louis Dutton's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    stylix.url = "github:danth/stylix";
    stylix.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      self,
      home-manager,
      nix-darwin,
      nixpkgs,
      stylix,
      sops-nix,
    }:
    let
      user = {
        name = "louis";
        displayName = "Louis Dutton";
        email = "louis@dutton.digital";
      };
      specialArgs = {
        inherit inputs user self;
        keymap = import ./keys.nix;
      };
      modules = [
        ./configuration.nix
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.${user.name} = import ./home;
          home-manager.backupFileExtension = "backup";
          home-manager.extraSpecialArgs = specialArgs;
        }
      ];
    in
    {
      homeConfigurations.nixos = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs { system = "aarch64-darwin"; };
        extraSpecialArgs = specialArgs;
        modules = [
          stylix.homeManagerModules.stylix
          ./home
        ];
      };

      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit specialArgs;
        system = "x86_64-linux";
        modules = modules ++ [
          ./linux
          home-manager.nixosModules.home-manager
          stylix.nixosModules.stylix
        ];
      };

      darwinConfigurations.nixos = nix-darwin.lib.darwinSystem {
        inherit specialArgs;
        system = "aarch64-darwin";
        modules = modules ++ [
          ./darwin
          home-manager.darwinModules.home-manager
          stylix.darwinModules.stylix
          sops-nix.darwinModules.sops
        ];
      };
    };
}
