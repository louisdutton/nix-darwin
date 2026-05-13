{...}: {
  imports = [
    ../../modules/matrix.nix
  ];

  matrix = {
    enable = true;
    serverName = "mini.taila65fcf.ts.net";
    enableCaddy = true;
    allowFederation = false;
    trustedServers = [];
  };
}
