{
  pkgs,
  user,
  inputs,
  config,
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
        nixos-rebuild switch \
          --flake .#homelab \
          --target-host homelab  \
          --build-host homelab \
          --fast
      '')
    ];
  };

  # ssh
  sops.secrets."ssh/homelab".owner = "louis";
  sops.secrets."ssh/mini".owner = "louis";
  programs.ssh = let
    homelab = "192.168.1.231";
    mini = "192.168.1.157";
  in {
    knownHosts = {
      homelab = {
        extraHostNames = ["homelab" homelab];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILzuc9CKsYm/sICfjH1Y8UYsEeX9zA8muWMQYRlS/Mbp";
      };
    };

    extraConfig = ''
      Host homelab
        HostName ${homelab}
        User root
        IdentityFile ${config.sops.secrets."ssh/homelab".path}
        Port 22
        IdentitiesOnly yes

      Host mini
        HostName ${mini}
        User root
        IdentityFile ${config.sops.secrets."ssh/mini".path}
        Port 22
        IdentitiesOnly yes
    '';
  };

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
