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
        "K" = "goto_file_start";
        "J" = "goto_last_line";
        "H" = "goto_line_start";
        "L" = "goto_line_end";
        ";" = "command_mode";
      };
    };

    extraPackages = with pkgs; [ nixd ];

    languages = {
      language-server = {
        biome = {
          command = "biome";
          args = [ "lsp-proxy" ];
        };
      };
      language = [
        {
          name = "nix";
          formatter.command = "${pkgs.nixfmt-rfc-style}/bin/nixfmt";
          auto-format = true;
        }
        {
          name = "typescript";
          language-servers = [
            {
              name = "typescript-language-server";
              except-features = [ "format" ];
            }
            "biome"
          ];
          auto-format = true;
        }
      ];
    };
  };
}
