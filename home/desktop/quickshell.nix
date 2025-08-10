{pkgs, ...}: {
  programs.quickshell = {
    enable = true;

    # activeConfig = "default";
    # configs.default = "~/.config/quickshell/default/shell.qml";
  };

  # Create .qmlls.ini for language server support
  xdg.configFile."quickshell/.qmlls.ini".text = "";
}
