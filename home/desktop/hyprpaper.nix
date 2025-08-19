{
  services.hyprpaper = {
    enable = true;
    settings = {
      splash = true;
      ipc = false;
      preload = [
        "~/projects/nixos/wallpapers/catppuccin.png"
      ];
      wallpaper = [
        ",~/projects/nixos/wallpapers/catppuccin.png"
      ];
    };
  };
}
