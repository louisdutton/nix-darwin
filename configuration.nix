{ pkgs, user, ... }:
{
  # nix
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # system shell
  programs.zsh.enable = true;
  programs.bash.enable = false;

  # users
  time.timeZone = "Europe/London";
  networking.hostName = "nixos";
  users.users.${user.name} = {
    shell = pkgs.zsh;
    description = user.displayName;
  };

  # theming
  stylix = {
    enable = true;
    image = ./totoro.png;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/everforest.yaml";
    opacity.terminal = 0.95;
    fonts.sizes.applications = 10;
    fonts.sizes.terminal = 14; # make dynamic based on machine
    fonts.monospace = {
      package = pkgs.nerdfonts.override { fonts = [ "JetBrainsMono" ]; };
      name = "JetBrainsMono Nerd Font";
    };
    targets.nixvim.enable = true;
  };
}
