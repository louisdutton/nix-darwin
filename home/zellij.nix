{config, ...}: {
  programs.zellij.enable = true;

  xdg.configFile."zellij/config.kdl".source =
    config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/projects/nixos/config/zellij/config.kdl";
}
