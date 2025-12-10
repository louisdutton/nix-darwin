{
  pkgs,
  user,
  inputs,
  config,
  lib,
  ...
}: {
  # nix
  nix = {
    nixPath = ["nixpkgs=${inputs.nixpkgs}"];
    channel.enable = false; # flakes > channels
    optimise.automatic = true;
    gc.automatic = true;
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  # users
  time.timeZone = "Europe/London";
  networking.hostName = "nixos";
  users.users.${user.name} = {
    description = user.displayName;
  };

  # aliases and custom utils
  environment = {
    variables = rec {
      EDITOR = "${lib.getExe pkgs.fugue}";
      VISUAL = EDITOR;
    };

    shellAliases = {
      e = "$EDITOR";
      g = "lazygit";
      clean = "git clean -xdf";
      l = "ls";
      la = "ls -a";
      ll = "ls -l";
      vibe = "caffeinate -d ${lib.getExe pkgs.opencode}";
    };

    systemPackages = with pkgs; [
      # re-deploy homelab nix configuration
      (writeShellScriptBin "lab-deploy" ''
        ${lib.getExe nixos-rebuild} switch \
          --flake .#homelab \
          --target-host homelab  \
          --build-host homelab \
          --fast
      '')
    ];
  };

  # secret management
  sops.defaultSopsFile = ./secrets.yml;
  sops.age.keyFile = "${config.users.users.${user.name}.home}/.config/sops/age/keys.txt";
  sops.age.generateKey = true;

  # theming
  stylix = {
    enable = true;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
    opacity.terminal = 1.0;
    fonts = {
      sizes.applications = 10;
      sizes.terminal = 11; # TODO make dynamic based on machine
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font";
      };
    };
  };
}
