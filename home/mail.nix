{pkgs, config, ...}: {
  home.packages = [pkgs.hydroxide];

  sops.age.keyFile = "/home/louis/.config/sops/age/keys.txt";
  sops.defaultSopsFile = ../secrets.yml;
  sops.secrets.hydroxide-password = {};

  programs.himalaya.enable = true;

  accounts.email.accounts.proton = {
    primary = true;
    address = "louis@dutton.digital";
    realName = "Louis Dutton";
    userName = "louis@dutton.digital";

    imap = {
      host = "127.0.0.1";
      port = 1143;
      tls.enable = false;
    };

    smtp = {
      host = "127.0.0.1";
      port = 1025;
      tls.enable = false;
    };

    passwordCommand = "cat ${config.sops.secrets.hydroxide-password.path}";

    himalaya = {
      enable = true;
      settings = {
        downloads-dir = "/home/louis/Downloads";
        "message.send.save-copy" = false;
      };
    };
  };

  systemd.user.services.hydroxide = {
    Unit = {
      Description = "Hydroxide - ProtonMail bridge";
      After = ["network.target"];
    };
    Service = {
      ExecStart = "${pkgs.hydroxide}/bin/hydroxide serve";
      Restart = "on-failure";
    };
    Install.WantedBy = ["default.target"];
  };
}
