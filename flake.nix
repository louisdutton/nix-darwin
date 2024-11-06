{
  description = "Louis Dutton's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";
    stylix.url = "github:danth/stylix";
    stylix.inputs.nixpkgs.follows = "nixpkgs";
    firefox-darwin.url = "github:bandithedoge/nixpkgs-firefox-darwin";
    firefox-darwin.inputs.nixpkgs.follows = "nixpkgs";
    firefox-addons.url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
    firefox-addons.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      self,
      home-manager,
      nix-darwin,
      nixpkgs,
      nixvim,
      stylix,
      firefox-darwin,
      ...
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
        ./vim
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
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit specialArgs;
        system = "x86_64-linux";
        modules = modules ++ [
          ./linux
          home-manager.nixosModules.home-manager
          nixvim.nixosModules.nixvim
          stylix.nixosModules.stylix
        ];
      };

      darwinConfigurations.nixos = nix-darwin.lib.darwinSystem {
        inherit specialArgs;
        system = "aarch64-darwin";
        modules = modules ++ [
          ./darwin
          home-manager.darwinModules.home-manager
          nixvim.nixDarwinModules.nixvim
          stylix.darwinModules.stylix
          {
            nixpkgs.overlays = [ firefox-darwin.overlay ];
          }
        ];
      };
    };
}
