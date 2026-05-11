{
  description = "XGX system configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:lnl7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {
    self,
    home-manager,
    nix-darwin,
    nixpkgs,
  }: let
    user = {
      name = "louis";
      displayName = "Louis Dutton";
      email = "louis@dutton.digital";
    };
    specialArgs = {
      inherit inputs user self;
    };
    system = "aarch64-darwin";
    pkgs = import nixpkgs {inherit system;};
  in {
    darwinConfigurations.nixos = nix-darwin.lib.darwinSystem {
      inherit specialArgs system;
      modules = [
        ./configuration.nix
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.${user.name} = import ./home;
          home-manager.backupFileExtension = "backup";
          home-manager.extraSpecialArgs = specialArgs;
        }
      ];
    };

    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs; [
        sops
        nixd
        alejandra
      ];
    };
  };
}
