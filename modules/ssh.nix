{user, ...}: let
  keys = {
    macbook = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICXEtgvjmOWvDFyMmg9YoK7eecoAOJLwGWzWMGKXQpkK";
    homelab = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILzuc9CKsYm/sICfjH1Y8UYsEeX9zA8muWMQYRlS/Mbp";
  };
  inherit (builtins) attrValues mapAttrs;
in {
  users.users.${user.name}.openssh.authorizedKeys.keys = attrValues keys;
  programs.ssh = {
    knownHosts = mapAttrs (k: v: {publicKey = v;}) keys;
  };
}
