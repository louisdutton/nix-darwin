{
  inputs,
  lib,
  pkgs,
  user,
  ...
}: {
  imports = [inputs.tether.nixosModules.default];

  services.tether = {
    enable = true;
    user = user.name;
    workspaceRoot = "/home/${user.name}/projects";
    listenAddress = "0.0.0.0";
    openFirewall = true;
    agents.codex = {
      command = lib.getExe inputs.tether.packages.${pkgs.stdenv.hostPlatform.system}.codex-acp;
      permanentDelete = {
        method = "_tether/session/delete_permanently";
      };
    };
    extraPackages = with pkgs; [nix ripgrep];
  };
}
