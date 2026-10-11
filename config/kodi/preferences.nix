{
  # Merge only these owned settings into writable guisettings.xml at startup.
  # Never freeze device UUIDs, display calibration, database state or history.
  gui = {
    # Gamescope lets native clients choose their buffer size, including when
    # its initial configure does not confirm Kodi's fullscreen request.
    "window.width" = 3840;
    "window.height" = 2160;
    "lookandfeel.skin" = "skin.theatre";
    "lookandfeel.skincolors" = "SKINDEFAULT";
    "lookandfeel.skintheme" = "SKINDEFAULT";
    "lookandfeel.enablerssfeeds" = false;
    "locale.language" = "resource.language.en_gb";
    "locale.timezonecountry" = "Britain (UK)";
    "locale.timezone" = "Europe/London";
    # Safe bootstrap/fallback. The router disables native joystick input only
    # after InputPlumber has actually provided our managed controller.
    "input.enablejoystick" = true;
    "input.enablemouse" = false;
    "input.asknewcontrollers" = false;
    "screensaver.mode" = "";
    "screensaver.usedimonpause" = false;
    "powermanagement.displaysoff" = 0;
    "powermanagement.shutdowntime" = 0;
    "services.webserver" = false;
    "services.esenabled" = true;
    "services.esallinterfaces" = false;
    "services.upnpserver" = false;
    "audiooutput.audiodevice" = "PIPEWIRE:Default|Default Output Device (PIPEWIRE)";
    "audiooutput.passthroughdevice" = "PIPEWIRE:Default|Default Output Device (PIPEWIRE)";
    "general.addonupdates" = 2; # Add-on versions are pinned by Nix, not Kodi.
    "debug.showloginfo" = false;
    # Native cadence for full-screen video; desktop refresh for the interface.
    "videoplayer.adjustrefreshrate" = 1; # Always
    "videolibrary.flattentvshows" = 2; # Always: one episode list across seasons.
    "filelists.showparentdiritems" = false; # Back navigates; no fake ".." poster.
  };
  advanced = {
    splash = "false";
    videolibrary.showemptytvshows = "true";
  };
  addonSettings."service.xbmc.versioncheck".versioncheck_enable = "false";
}
