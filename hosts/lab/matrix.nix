{...}: {
  # CREATE ROLE "matrix-synapse";
  # CREATE DATABASE "matrix-synapse" WITH OWNER "matrix-synapse"
  # TEMPLATE template0
  # LC_COLLATE = "C"
  # LC_CTYPE = "C";
  services.postgresql = {
    enable = true;
    ensureDatabases = ["matrix-synapse"];
    ensureUsers = [
      {
        name = "matrix-synapse";
        ensureDBOwnership = true;
      }
    ];
  };

  # expose matrix http (private network only)
  networking.firewall.allowedTCPPorts = [8008];

  services.matrix-synapse = {
    enable = true;

    enableRegistrationScript = true;

    # TODO: setup sops-nix for homelab secrets
    settings.enable_registration = true;
    settings.enable_registration_without_verification = true;
    settings.registration_shared_secret = "fc9c138b983310b4616c3b2d9a21fb8f66982ca206685f27a68b5c958c426d3151c57b1a7b4f8a759f88";

    # settings.public_baseurl = baseUrl;
    settings.server_name = "dutton.digital";
    settings.listeners = [
      {
        port = 8008;
        bind_addresses = ["0.0.0.0"];
        type = "http";
        tls = false;
        x_forwarded = true;
        resources = [
          {
            names = [
              "client"
              "federation"
            ];
            compress = true;
          }
        ];
      }
    ];
  };
}
