{config, ...}: {
  # tuwunel runs on 6167 but will probably need to put this behind a reverse proxy
  networking.firewall.allowedTCPPorts = [6167];

  # not using synapse because it's tied to element
  sops.secrets.matrix_registration_token.owner = config.services.matrix-tuwunel.user;
  services.matrix-tuwunel = {
    enable = true;
    settings.global = {
      server_name = "homelab";
      address = ["0.0.0.0"];
      allow_registration = true;
      registration_token_file = config.sops.secrets.matrix_registration_token.path;
    };
  };
}
