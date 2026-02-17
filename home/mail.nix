{pkgs, ...}: {
  home.packages = [
    pkgs.hydroxide
    pkgs.himalaya
  ];

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
