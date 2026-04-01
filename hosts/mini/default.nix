{
  config,
  pkgs,
  lib,
  ...
}: let
  whisper-model = pkgs.fetchurl {
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin";
    hash = "sha256-oDd5yG3zMjB19eeWyyzlAp8A7Ihp7uP9+4l6/jbG0AI=";
  };
in {
  imports = [
    ./hardware-configuration.nix
    ../../modules/configuration.nix
    ../../modules/asahi.nix
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

  services.agent = {
    enable = true;
    user = "louis";
  };

  services.tailscale = {
    enable = true;
    permitCertUid = "caddy";
  };

  # Caddy reverse proxy with Tailscale HTTPS
  services.caddy = {
    enable = true;
    virtualHosts."mini.taila65fcf.ts.net" = {
      extraConfig = let
        cfg = config.services.agent;
      in ''
        root * ${cfg.clientPackage}
        file_server

        handle /api/* {
          # Disable buffering for SSE streaming
          reverse_proxy 127.0.0.1:${toString cfg.port} {
            flush_interval -1
            transport http {
              versions 1.1
            }
          }
        }
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

  # GitHub Actions runner for xgx-ai/auno
  sops.secrets.github-runner-token = {};
  services.github-runners.auno = {
    enable = true;
    url = "https://github.com/xgx-ai";
    tokenFile = config.sops.secrets.github-runner-token.path;
    name = "louis-mini";
    extraLabels = ["nixos" "aarch64-linux"];
  };

  system.stateVersion = "25.11";

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "claude-code"
    ];
}
