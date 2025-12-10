{
  description = "Louis Dutton's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:lnl7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    stylix.url = "github:danth/stylix";
    stylix.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    fugue.url = "github:louisdutton/fugue";
    fugue.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {
    self,
    home-manager,
    nix-darwin,
    nixpkgs,
    stylix,
    sops-nix,
    fugue,
  }: let
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

        # fugue: my custom editor
        nixpkgs.overlays = [fugue.overlays.default];
      }
    ];
  in {
    homeConfigurations.nixos = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs rec {
        system = "aarch64-darwin";
        # overlays = [(final: prev: {inherit (fugue.packages.${system}) fugue;})];
      };
      extraSpecialArgs = specialArgs;
      modules = [
        stylix.homeManagerModules.stylix
        ./home
      ];
    };

    darwinConfigurations.nixos = nix-darwin.lib.darwinSystem {
      inherit specialArgs;
      system = "aarch64-darwin";
      modules =
        modules
        ++ [
          ./darwin
          home-manager.darwinModules.home-manager
          stylix.darwinModules.stylix
          sops-nix.darwinModules.sops
        ];
    };

    devShells.aarch64-darwin.default = let
      pkgs = import nixpkgs {system = "aarch64-darwin";};
    in
      with pkgs;
        mkShell {
          packages = [
            sops
            nixd
            lua-language-server
            alejandra
          ];
        };
  };
}
