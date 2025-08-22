{...}: {
  qt.enable = true; # for qmlls
  programs.quickshell = {
    systemd.enable = true;
    systemd.target = "hyprland-session.target";
    enable = true;
  };

  # Create .qmlls.ini for language server support
  # xdg.configFile."quickshell/.qmlls.ini".text = "";
}
