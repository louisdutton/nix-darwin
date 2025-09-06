{pkgs, ...}: {
  environment = {
    systemPackages = with pkgs; [
      sops

      # converts an ssh ed25519 public key to an age key for sops access
      # this key can used to grant secret access to a target machine.
      # to do this, add the key to .sops.yaml and run `sops updatekeys secrets.yml`
      (writeShellScriptBin "sops-ssh-to-age" ''
        ssh-keyscan $1 | ${pkgs.ssh-to-age}/bin/ssh-to-age
      '')

      # creates the initial master age key used to configure sops
      # this should only need to be done once on the master system.
      (writeShellScriptBin "sops-generate-master" ''
        ${pkgs.age}/bin/age-keygen -o ~/.config/sops/age/keys.txt
      '')
    ];
  };

  # secrets.yml contains encrypted secrets that can only be
  # accessed by machines specified in .sops.yaml (by ssh-derived age key)
  sops = {
    defaultSopsFile = ../secrets.yml;
  };
}
