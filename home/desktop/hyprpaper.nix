{
  services.hyprpaper = {
    enable = true;
    settings = {
      splash = true;
      ipc = false;
      preload = [
        "~/.config/nixos/wallpapers/catppuccin.png"
      ];
      wallpaper = [
        ",~/.config/nixos/wallpapers/catppuccin.png"
      ];
    };
  };
}