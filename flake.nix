{
  description = "Louis Dutton's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    apple-silicon.url = "github:tpwrules/nixos-apple-silicon";
    apple-silicon.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    home-manager,
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
  in {
    packages.x86_64-linux = let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
      preview = import ./pkgs/kodi {
        inherit pkgs;
        homeDirectory = "/home/${user.name}";
        preview = true;
      };
    in {
      theatre-skin = preview.skin;
      theatre-kodi-preview = preview.package;
    };

    checks.x86_64-linux.theatre-skin =
      nixpkgs.legacyPackages.x86_64-linux.runCommand "theatre-skin-check" {
        nativeBuildInputs = [nixpkgs.legacyPackages.x86_64-linux.python3];
      } ''
        python3 ${./tests/kodi/test_skin.py} ${./config/kodi/skin.theatre}
        touch "$out"
      '';

    checks.x86_64-linux.inputplumber = import ./tests/inputplumber.nix {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      inherit nixpkgs;
    };

    nixosConfigurations.mini = nixpkgs.lib.nixosSystem {
      inherit specialArgs;
      system = "aarch64-linux";
      modules = modules ++ [./hosts/mini];
    };

    nixosConfigurations.ideapad = nixpkgs.lib.nixosSystem {
      inherit specialArgs;
      system = "x86_64-linux";
      modules = modules ++ [./hosts/ideapad];
    };

    nixosConfigurations.theatre = nixpkgs.lib.nixosSystem {
      inherit specialArgs;
      system = "x86_64-linux";
      modules = modules ++ [./hosts/theatre];
    };
  };
}
