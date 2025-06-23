{...}: {
  # setup: ssh-keygen -f ~/.ssh/homelab && ssh-copy-id -i ~/.ssh/homelab 192.168.1.231
  programs.ssh = {
    enable = true;
    extraConfig =
      # ssh
      ''
        Host homelab
          HostName 192.168.1.231
          User root
          IdentityFile ~/.ssh/homelab
          Port 22
          IdentitiesOnly yes
      '';
  };
}
