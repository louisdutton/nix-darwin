{ pkgs, ... }:
{
  programs.helix = {
    enable = true;
    package = pkgs.evil-helix;
  };

  programs.helix.settings = {
    editor = {
      cursor-shape.insert = "bar";
    };
    keys.normal = {
      space.f = "file_picker";
      space.a = "code_action";
      ";" = "command_mode";
    };
  };
}
