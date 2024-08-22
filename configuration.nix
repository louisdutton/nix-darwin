{ pkgs, user, ... }:
{
  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;
  nix.package = pkgs.nix;

  # Necessary for using flakes on this system.
  nix.settings.experimental-features = [ "nix-command" "flakes"];

  # zsh > bash
  programs.zsh.enable = true;

  # default host and user
  networking.hostName = user.hostName;
  users = {
    # defaultUserShell = pkgs.zsh; # nixos only
    users.${user.name} = {
      shell = pkgs.zsh;
      home = user.home;
      # isNormalUser = true; # nixos only
    };
  };

  # nix helper (nixos only)
  # programs.nh = {
  #   enable = true;
  #   flake = user.flake;
  # };

  # docker
  # virtualisation.docker.enable = true;
  # users.${user.name}.extraGroups = [ "docker" ];
}
