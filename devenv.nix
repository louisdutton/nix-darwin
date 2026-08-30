{pkgs, ...}: {
  packages = [pkgs.sops];

  languages = {
    nix.enable = true;
    lua.enable = true;
  };

  treefmt = {
    enable = true;
    config.programs.alejandra.enable = true;
  };
}
