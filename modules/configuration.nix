{
  pkgs,
  user,
  inputs,
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

  # networking
  networking.networkmanager.enable = true;

  # users
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;
  users.users.${user.name} = {
    isNormalUser = true;
    description = user.displayName;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  # locale
  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";

  # keymap
  console.keyMap = "uk";
  services.xserver.xkb = {
    layout = "gb";
    variant = "";
  };

  # aliases and custom utils
  environment = {
    variables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };

    shellAliases = {
      e = "$EDITOR";
      g = "lazygit";
    };

    systemPackages = with pkgs; [
      git
      neovim
      gcc # required by neovim
      wl-clipboard

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
  # sops.defaultSopsFile = ./secrets.yml;
  # sops.age.keyFile = "${config.users.users.${user.name}.home}/.config/sops/age/keys.txt";
  # sops.age.generateKey = true;

  # theming
  stylix = {
    enable = true;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
    opacity.terminal = 1.0;
    fonts = {
      sizes.applications = 10;
      sizes.terminal = 12;
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font";
      };
    };
  };
}
