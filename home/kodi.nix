{
  config,
  pkgs,
  ...
}: let
  kodi = import ../pkgs/kodi {
    inherit pkgs;
    homeDirectory = config.home.homeDirectory;
  };
  assets = ../config/kodi;
  userdata = ".kodi/userdata";
in {
  programs.kodi = {
    enable = true;
    package = kodi.package;
    settings = kodi.preferences.advanced;
    addonSettings = kodi.preferences.addonSettings;
    sources.video = {
      default = "";
      source =
        map (source: {
          name =
            if source.content == "movies"
            then "Films"
            else "TV Shows";
          inherit (source) path;
          allowsharing = "false";
        })
        kodi.mediaSources;
    };
  };

  home.file = {
    "${userdata}/keymaps/local-home-gamepad.xml".source = assets + /gamepad.xml;
    "${userdata}/addon_data/peripheral.joystick/resources/buttonmaps/xml/linux/Pro_Controller_14b_6a.xml".source = assets + /Pro_Controller_14b_6a.xml;
  };
}
