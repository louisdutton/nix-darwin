{
  ...
}:

{
  # CREATE ROLE "matrix-synapse";
  # CREATE DATABASE "matrix-synapse" WITH OWNER "matrix-synapse"
  # TEMPLATE template0
  # LC_COLLATE = "C"
  # LC_CTYPE = "C";
  services.postgresql = {
    enable = true;
    ensureDatabases = [ "matrix-synapse" ];
    ensureUsers = [
      {
        name = "matrix-synapse";
        ensureDBOwnership = true;
      }
    ];
  };

  # expose matrix http (private network only)
  networking.firewall.allowedTCPPorts = [ 8008 ];

  services.matrix-synapse = {
    enable = true;
    settings.enable_registration = true;
    settings.server_name = "dutton.digital";
    # settings.public_baseurl = baseUrl;
    settings.listeners = [
      {
        port = 8008;
        bind_addresses = [ "::1" ];
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
