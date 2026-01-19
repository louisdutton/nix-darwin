{...}: {
  qt.enable = true; # for qmlls
  programs.quickshell = {
    enable = true;
    systemd.enable = true;
    systemd.target = "graphical-session.target"; # UWSM manages this properly
  };

  # Create .qmlls.ini for language server support
  # xdg.configFile."quickshell/.qmlls.ini".text = "";
}
