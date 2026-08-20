{...}: {
  imports = [
    ../../modules/matrix.nix
  ];

  matrix = {
    enable = false;
    serverName = "mini.taila65fcf.ts.net";
    enableCaddy = true;
    allowFederation = false;
    trustedServers = [];
  };
}
