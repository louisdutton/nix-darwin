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
    system = "aarch64-darwin";
    pkgs = import nixpkgs {inherit system;};
  in {
    darwinConfigurations.nixos = nix-darwin.lib.darwinSystem {
      inherit specialArgs system;
      modules = [
        ./configuration.nix
        ./darwin
        home-manager.darwinModules.home-manager
        stylix.darwinModules.stylix
        sops-nix.darwinModules.sops
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.${user.name} = import ./home;
          home-manager.backupFileExtension = "backup";
          home-manager.extraSpecialArgs = specialArgs;

          # fugue editor
          nixpkgs.overlays = [
            fugue.overlays.default
            fugue.overlays.tree-sitter
          ];
        }
      ];
    };

    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs; [
        sops
        nixd
        lua-language-server
        alejandra
      ];

      shellHook = ''
        echo 'link nvim config: ln -s $PWD/config/* ~/.config'
      '';
    };
  };
}
