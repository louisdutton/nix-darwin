{
  pkgs,
  user,
  inputs,
  config,
  ...
}:
{
  # nix
  nix = {
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
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
    variables = {
      EDITOR = "hx";
      VISUAL = "hx";
    };

    shellAliases = {
      e = "hx";
      g = "lazygit";
      clean = "git clean -xdf";
      l = "ls";
      la = "ls -a";
      ll = "ls -l";
    };
  };

  # secret management
  sops.defaultSopsFile = ./secrets.yml;
  sops.age.keyFile = "${config.users.users.${user.name}.home}/.config/sops/age/keys.txt";
  sops.age.generateKey = true;
  sops.secrets.linear.owner = user.name;
  environment.systemPackages =
    let
      query = # graphql
        ''
          { issues { nodes { id title } } }
        '';
      issues = pkgs.writeShellScriptBin "linear-issues" ''
        TOKEN=$(cat ${config.sops.secrets.linear.path})
        xh https://api.linear.app/graphql Authorization:$TOKEN query="${query}" |
        jq '.data.issues.nodes | .[] | "\(.id)\t\(.title)"' -r |
        fzf
      '';
    in
    [
      issues
    ];

  # theming
  stylix = {
    enable = true;
    image = ./wallpapers/waves.jpg;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-frappe.yaml";
    opacity.terminal = 1.0;
    fonts.sizes.applications = 10;
    fonts.sizes.terminal = 14; # TODO make dynamic based on machine
    fonts.monospace = {
      package = pkgs.nerd-fonts.jetbrains-mono;
      name = "JetBrainsMono Nerd Font";
    };
  };
}
