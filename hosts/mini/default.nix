{
  config,
  pkgs,
  lib,
  ...
}: {
  home-manager.users.louis = {
    systemd.user.services.agent = {
      Unit = {
        Description = "Agent service";
        After = ["network.target"];
      };
      Service = {
        Type = "simple";
        WorkingDirectory = "%h/projects/agent";
        ExecStart = "${pkgs.zsh}/bin/zsh -l -c 'nix run'";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install = {
        WantedBy = ["default.target"];
      };
    };
  };
  imports = [
    ./hardware-configuration.nix
    ../../modules/configuration.nix
    ../../modules/asahi.nix
    ../../modules/desktop.nix
    ../../modules/sops.nix
  ];

  networking.hostName = "mini";
  services.openssh.enable = true;

  # bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General.Experimental = true; # enable device battery status
  };

  # keyboard
  hardware.keyboard.zsa.enable = true;

  environment = {
    shellAliases = {
      rebuild = "sudo nixos-rebuild switch --impure --flake ~/projects/nixos";
    };
  };

  services.tailscale = {
    enable = true;
    permitCertUid = "caddy";
  };

  # Agent Mobile
  services.agent = {
    enable = false;
    user = "louis";
    group = "users";
  };

  # Caddy reverse proxy with Tailscale HTTPS
  services.caddy = {
    enable = true;
    virtualHosts."mini.taila65fcf.ts.net" = {
      extraConfig = ''
        reverse_proxy 127.0.0.1:9370
      '';
    };
  };

  system.stateVersion = "25.11";

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "claude-code"
    ];
}
