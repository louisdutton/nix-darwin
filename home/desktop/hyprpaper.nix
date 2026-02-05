{
  services.hyprpaper = {
    enable = true;
    settings = {
      splash = true;
      ipc = true;
      wallpaper = [
        {
          monitor = "";
          path = builtins.toString ../../wallpapers/catppuccin.png;
        }
      ];
    };
  };
}
