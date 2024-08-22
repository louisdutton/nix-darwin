{ pkgs, user, ... }:
{
  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;
  nix.package = pkgs.nix;

  # Necessary for using flakes on this system.
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # zsh > bash
  programs.zsh.enable = true;

  # host and user
  networking.hostName = user.hostName;
  users = {
    users.${user.name} = {
      shell = pkgs.zsh;
      home = user.home;
    };
  };

  # docker
  # virtualisation.docker.enable = true;
  # users.${user.name}.extraGroups = [ "docker" ];
}
