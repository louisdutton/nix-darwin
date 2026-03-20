{
  pkgs,
  lib,
  ...
}: let
  whisper-model = pkgs.fetchurl {
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin";
    hash = "sha256-oDd5yG3zMjB19eeWyyzlAp8A7Ihp7uP9+4l6/jbG0AI=";
  };
in {
  home-manager.users.louis = {
    systemd.user.services.agent-server = {
      Unit = {
        Description = "Agent bun server";
        After = ["network.target"];
      };
      Service = {
        Type = "simple";
        WorkingDirectory = "%h/projects/agent";
        ExecStart = "${pkgs.zsh}/bin/zsh -l -c 'nix develop -c bun serve --port 9370'";
        Restart = "on-failure";
        RestartSec = 2;
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

  environment = {
    shellAliases = {
      rebuild = "sudo nixos-rebuild switch --impure --flake ~/projects/nixos";
    };
  };

  services.tailscale = {
    enable = true;
    permitCertUid = "caddy";
  };

  # Caddy reverse proxy with Tailscale HTTPS
  services.caddy = {
    enable = true;
    virtualHosts."mini.taila65fcf.ts.net" = {
      extraConfig = ''
        reverse_proxy 127.0.0.1:9370
      '';
    };
    # Whisper transcription (whisper.cpp already sends CORS headers)
    virtualHosts."mini.taila65fcf.ts.net:9376" = {
      extraConfig = ''
        reverse_proxy 127.0.0.1:5932
      '';
    };
  };

  systemd.services.whisper-server = {
    description = "Whisper.cpp HTTP server";
    after = ["network.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.whisper-cpp}/bin/whisper-server --host 0.0.0.0 --port 5932 --model ${whisper-model}";
      Restart = "on-failure";
      RestartSec = 5;
      DynamicUser = true;
      StateDirectory = "whisper";
    };
  };

  system.stateVersion = "25.11";

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "claude-code"
    ];
}
