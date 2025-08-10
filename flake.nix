{
  description = "Louis Dutton's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    stylix.url = "github:danth/stylix";
    stylix.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {
    self,
    home-manager,
    nixpkgs,
    stylix,
    sops-nix,
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
      }
    ];
  in {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      inherit specialArgs;
      system = "x86_64-linux";
      modules =
        modules
        ++ [
          ./linux
          home-manager.nixosModules.home-manager
          stylix.nixosModules.stylix
          sops-nix.nixosModules.sops
        ];
    };

    nixosConfigurations.homelab = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./lab
      ];
    };

    devShells.x86_64-linux.default = let
      pkgs = import nixpkgs {system = "x86_64-linux";};
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
