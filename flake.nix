{
  description = "Louis Dutton's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    stylix.url = "github:danth/stylix";
    stylix.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    apple-silicon.url = "github:tpwrules/nixos-apple-silicon";
    apple-silicon.inputs.nixpkgs.follows = "nixpkgs";
    agent.url = "github:louisdutton/agent";
    agent.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    flake-utils,
    home-manager,
    stylix,
    sops-nix,
    ...
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
      home-manager.nixosModules.home-manager
      stylix.nixosModules.stylix
      sops-nix.nixosModules.sops
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.users.${user.name} = import ./home;
        home-manager.backupFileExtension = "backup";
        home-manager.extraSpecialArgs = specialArgs;
        home-manager.sharedModules = [
          sops-nix.homeManagerModules.sops
        ];
      }
    ];
  in
    {
      nixosConfigurations.mini = nixpkgs.lib.nixosSystem {
        inherit specialArgs;
        system = "aarch64-linux";
        modules = modules ++ [./hosts/mini inputs.agent.nixosModules.agent];
      };

      nixosConfigurations.ideapad = nixpkgs.lib.nixosSystem {
        inherit specialArgs;
        system = "x86_64-linux";
        modules = modules ++ [./hosts/ideapad];
      };

      nixosConfigurations.homelab = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/lab
          sops-nix.nixosModules.sops
        ];
      };
    }
    // flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      devShells.default = with pkgs;
        mkShell {
          packages = [
            sops
            nixd
            lua-language-server
            alejandra
          ];

          shellHook = ''
            rm -r ~/.config/nvim ~/.config/quickshell
            ln -s $PWD/config/* ~/.config
          '';
        };
    });
}
