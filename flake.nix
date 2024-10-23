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
      home-manager,
      nix-darwin,
      nixpkgs,
      nixvim,
      stylix,
      firefox-darwin,
      ...
    }:
    let
      shared = {
        name = "louis";
        displayName = "Louis Dutton";
        email = "louis@dutton.digital";
      };
      baseModules = [
        ./configuration.nix
        ./vim
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.louis = import ./home;
          home-manager.backupFileExtension = "backup";
        }
      ];
    in
    {
      nixosConfigurations.nixos =
        let
          user = shared // {
            rebuildCmd = "nixos-rebuild";
          };
        in
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit user;
          };
          modules = baseModules ++ [
            ./linux.nix
            home-manager.nixosModules.home-manager
            nixvim.nixosModules.nixvim
            stylix.nixosModules.stylix
            {
              home-manager.extraSpecialArgs = {
                inherit user;
              };
            }
          ];
        };

      darwinConfigurations.nixos =
        let
          user = shared // {
            rebuildCmd = "darwin-rebuild";
          };
        in
        nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = {
            inherit user;
            inherit inputs;
          };
          modules = baseModules ++ [
            ./darwin.nix
            home-manager.darwinModules.home-manager
            nixvim.nixDarwinModules.nixvim
            stylix.darwinModules.stylix
            {
              nixpkgs.overlays = [ firefox-darwin.overlay ];
              home-manager.extraSpecialArgs = {
                inherit user;
                inherit inputs;
              };
            }
          ];
        };
    };
}
