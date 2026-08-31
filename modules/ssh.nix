{user, ...}: let
  keys = {
    macbook = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILKLL8byTkpIyx1ohQMT428LyifRsfv2uboqAP9FE7cO";
  };
  inherit (builtins) attrValues mapAttrs;
in {
  users.users.${user.name}.openssh.authorizedKeys.keys = attrValues keys;
  programs.ssh = {
    knownHosts = mapAttrs (k: v: {publicKey = v;}) keys;
    extraConfig = ''
      Host theatre theatre.lan
        # Detect a broken LAN path instead of leaving the terminal hung forever.
        ServerAliveInterval 15
        ServerAliveCountMax 3
    '';
  };
}
