{...}: {
  # setup: ssh-keygen -f ~/.ssh/homelab && ssh-copy-id -i ~/.ssh/homelab 192.168.1.231
  programs.ssh = {
    enable = true;
    extraConfig = ''
      Host homelab
        HostName 192.168.1.231
        User root
        IdentityFile ~/.ssh/homelab
        Port 22
        IdentitiesOnly yes

      Host mini
        HostName 192.168.1.157
        User root
        IdentityFile ~/.ssh/mini
        Port 22
        IdentitiesOnly yes
    '';
  };
}
