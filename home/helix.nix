{ pkgs, ... }:
{
  programs.helix = {
    enable = true;
    package = pkgs.evil-helix;
    settings = {
      editor = {
        cursor-shape.insert = "bar";
      };
      keys.normal = {
        ";" = "command_mode";
      };
    };
  };

  programs.helix.languages.language = [
    { name = "rust"; }
    {
      name = "nix";
      auto-format = true;
      formatter.command = "${pkgs.nixfmt}/bin/nixfmt";
    }
    { name = "typescript"; }
  ];
}
