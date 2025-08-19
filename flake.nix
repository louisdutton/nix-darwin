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
    apple-silicon.url = "github:tpwrules/nixos-apple-silicon";
    apple-silicon.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {
    self,
    home-manager,
    nixpkgs,
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
      }
    ];
  in {
    nixosConfigurations.mini = nixpkgs.lib.nixosSystem {
      inherit specialArgs;
      system = "aarch64-linux";
      modules = modules ++ [./hosts/mini];
    };

    # nixosConfigurations.laptop = nixpkgs.lib.nixosSystem {
    #   inherit specialArgs;
    #   system = "x86_64-linux";
    #   modules = modules ++ [ ./hosts/laptop ];
    # };
    #
    # nixosConfigurations.homelab = nixpkgs.lib.nixosSystem {
    #   system = "x86_64-linux";
    #   modules = [ ./lab ];
    # };

    devShells.aarch64-linux.default = let
      pkgs = import nixpkgs {system = "aarch64-linux";};
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
