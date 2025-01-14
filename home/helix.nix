{ pkgs, self, ... }:
{
  programs.helix = {
    enable = true;
    package = pkgs.evil-helix;
    settings = {
      theme = "catppuccin_frappe";
      editor = {
        mouse = false;
        cursor-shape.insert = "bar";
        gutters = [
          "diagnostics"
          "diff"
          "line-numbers"
        ];
        end-of-line-diagnostics = "hint";
        inline-diagnostics = {
          cursor-line = "warning";
        };
        completion-timeout = 5;
      };
      keys.insert = {
        "C-space" = "completion";
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
      nodePackages.vscode-langservers-extracted
    ];

    languages = {
      language-server = {
        # FIXME
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
      language =
        let
          withBiome = name: [
            {
              inherit name;
              except-features = [ "format" ];
            }
            "biome"
          ];
        in
        [
          {
            name = "nix";
            formatter.command = "${pkgs.nixfmt-rfc-style}/bin/nixfmt";
            auto-format = true;
          }
          {
            name = "json";
            language-servers = withBiome "vscode-json-language-server";
            auto-format = true;
          }
          {
            name = "css";
            language-servers = withBiome "vscode-css-language-server";
            auto-format = true;
          }
        ]
        ++
          map
            (name: {
              inherit name;
              language-servers = withBiome "typescript-language-server";
              auto-format = true;
            })
            [
              "typescript"
              "javascript"
              "tsx"
              "jsx"
            ];
    };
  };
}
