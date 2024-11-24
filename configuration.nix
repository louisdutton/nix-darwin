{
  pkgs,
  user,
  inputs,
  ...
}:
{
  # nix
  nixpkgs.config.allowUnfree = true;
  nix = {
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  # system shell
  programs.zsh.enable = true;

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
    image = ./wallpapers/catppuccin.png;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-frappe.yaml";
    opacity.terminal = 1.0;
    fonts.sizes.applications = 10;
    fonts.sizes.terminal = 14; # TODO make dynamic based on machine
    fonts.monospace = {
      package = pkgs.nerdfonts.override { fonts = [ "JetBrainsMono" ]; };
      name = "JetBrainsMono Nerd Font";
    };

    targets.nixvim.transparentBackground.main = true;
    targets.nixvim.transparentBackground.signColumn = true;
    targets.nixvim.plugin = "base16-nvim";
  };

  home-manager.users.louis.stylix.targets.nixvim.transparentBackground.main = true;
  home-manager.users.louis.stylix.targets.nixvim.transparentBackground.signColumn = true;
}
