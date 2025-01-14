{ pkgs, self, ... }:
{
  programs.helix = {
    enable = true;
    package = pkgs.evil-helix;
    settings = {
      theme = "catppuccin_frappe";
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

    extraPackages = with pkgs; [
      nixd
      nodePackages.typescript-language-server
    ];

    languages = {
      language-server = {
        nixd.config.settings.options =
          let
            # system = ''''${builtins.currentSystem)}'';
            flake = ''(builtins.getFlake "${self}")'';
          in
          rec {
            nixos.expr = "${flake}.darwinConfigurations.nixos.options";
            home-manager.expr = "${nixos.expr}.home-manager.users.type.getSubOptions [ ]";
          };
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
