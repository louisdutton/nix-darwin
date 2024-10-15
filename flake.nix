{
  description = "Louis Dutton's nixos configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";
    stylix.url = "github:danth/stylix";
    stylix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      home-manager,
      nixpkgs,
      nixvim,
      stylix,
      ...
    }:
    let
      shared = rec {
        name = "louis";
        home = /Users/${name};
        flake = home + /projects/nixos;
        displayName = "Louis Dutton";
        email = "louis@dutton.digital";
      };
    in
    {
      nixosConfigurations.nixos =
        let
          user = shared // {
            system = "x86_64-linux";
          };
        in
        nixpkgs.lib.nixosSystem {
          system = user.system;
          specialArgs = {
            inherit user;
          };
          modules = [
            ./configuration.nix
            ./vim
            home-manager.nixosModules.home-manager
            nixvim.nixosModules.nixvim
            stylix.nixosModules.stylix
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.louis = import ./home;
              home-manager.backupFileExtension = "backup";
              home-manager.extraSpecialArgs = {
                inherit user;
              };
            }
          ];
        };
    };
}
