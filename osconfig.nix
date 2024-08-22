{ pkgs, user, ... }:
{
  system.stateVersion = "23.11";
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  networking.hostName = user.hostName;
  users = {
    defaultUserShell = pkgs.zsh;
    users.${user.name} = {
      isNormalUser = true;
      extraGroups = [ "docker" ];
    };
  };

  programs.zsh.enable = true;
  programs.nh = {
    enable = true;
    flake = user.flake;
  };

  virtualisation.docker.enable = true;

  # keyboard
  hardware.keyboard.qmk.enable = true;
  services.udev.packages = with pkgs; [ via ];

  environment.systemPackages = with pkgs; [
    xclip # clipboard
    via # qmk hot-reload
  ];
}
