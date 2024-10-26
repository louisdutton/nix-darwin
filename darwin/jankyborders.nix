{ config, ... }:
{
  services.jankyborders = {
    enable = true;
    width = 3.0;
    order = "above";
    active_color = "0xff${config.lib.stylix.colors.base0D}";
    inactive_color = "0xff${config.lib.stylix.colors.base03}";
    hidpi = false;
  };
}
