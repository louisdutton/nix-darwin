{
  description = "Louis Dutton's darwin configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nix-darwin, home-manager, nixvim, ... }:
  let
      shared = rec {
        name = "louis";
        home = /Users/${name};
        flake = home + /.config/nix-darwin;
        displayName = "Louis Dutton";
        email = "louis.dutton@travelchapter.com";
      };
  in
  {
    darwinConfigurations."mini" =
    let
	user = shared // {	
	 system = "aarch64-darwin";
	 hostName = "mini";
	};
    in
    nix-darwin.lib.darwinSystem {
	system = user.system;
	specialArgs = {
		inherit user;
	};
      modules = [
        ./configuration.nix
        ./macos.nix
	./vim
        home-manager.darwinModules.home-manager
	nixvim.nixDarwinModules.nixvim
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
