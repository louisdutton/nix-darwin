{ pkgs, ... }:
{
  services.skhd = {
    enable = true;
    package = pkgs.skhd;
    skhdConfig = ''
      # restart services
      cmd + shift - r : yabai --restart-service && skhd --restart-service

      # arrow keys
      ctrl - h : skhd -k left
      ctrl - j : skhd -k down
      ctrl - k : skhd -k up
      ctrl - l : skhd -k right

      # unique programs
      cmd - n : alacritty
      cmd - space : ${pkgs.raycast}/Applications/Raycast.app/Contents/MacOS/Raycast
      cmd - b : ${pkgs.firefox-devedition-bin}/Applications/Firefox\ Developer\ Edition.app/Contents/MacOS/firefox

      # space navigation
      cmd - 1 : yabai -m space --focus 1
      cmd - 2 : yabai -m space --focus 2
      cmd - 3 : yabai -m space --focus 3

      # window navigation
      cmd - h : yabai -m window --focus west
      cmd - j : yabai -m window --focus south
      cmd - k : yabai -m window --focus north
      cmd - l : yabai -m window --focus east

      # window movement
      cmd + ctrl - h : yabai -m window --swap west
      cmd + ctrl - j : yabai -m window --swap south
      cmd + ctrl - k : yabai -m window --swap north
      cmd + ctrl - l : yabai -m window --swap east

      # window zoom
      cmd - d : yabai -m window --toggle zoom-parent
      cmd - f : yabai -m window --toggle zoom-fullscreen
    '';
  };
}
