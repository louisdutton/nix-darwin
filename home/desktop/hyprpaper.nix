{
  services.hyprpaper = {
    enable = true;
    settings = {
      splash = true;
      ipc = true;
      wallpaper = [
        {
          monitor = "";
          # path = "~/projects/nixos/wallpapers/catppuccin.png";
          path = builtins.toString ../../wallpapers/catppuccin.png;
        }
      ];
    };
  };
}
