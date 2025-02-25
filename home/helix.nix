{ pkgs, self, ... }:
{
  programs.helix = {
    enable = true;
    # package = pkgs.evil-helix;
    themes.catppuccin = {
      inherits = "catppuccin_frappe";
      "ui.background" = {
        bg = "transparent";
      };
    };
    settings = {
      theme = "catppuccin";
      editor = {
        mouse = false;
        cursor-shape.insert = "bar";
        gutters = [
          "diagnostics"
          "line-numbers"
          "diff"
        ];
        end-of-line-diagnostics = "hint";
        inline-diagnostics = {
          cursor-line = "warning";
        };
        completion-timeout = 5;
      };
      keys =
        let
          megaNav = {
            K = "goto_file_start";
            J = "goto_last_line";
            H = "goto_line_start";
            L = "goto_line_end";
          };
        in
        {
          insert = {
            "C-space" = "completion";
          };
          normal = {
            ";" = "command_mode";
            "'" = "collapse_selection";
            space.f = "file_picker_in_current_directory";
            space.F = "file_picker";
          } // megaNav;
          select = {
            u = "switch_to_lowercase";
            U = "switch_to_uppercase";
          } // megaNav;
        };
    };

    extraPackages = with pkgs; [
      nixd
      nodePackages.typescript-language-server
      nodePackages.vscode-langservers-extracted
      tailwindcss-language-server
      gopls
      golangci-lint-langserver
      emmet-ls
      yaml-language-server
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
        emmet-ls = {
          command = "emmet-ls";
          args = [ "--stdio" ];
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
            name = "go";
            language-servers = [
              "gopls"
              "golangci-lint-langserver"
            ];
            auto-format = true;
          }
          {
            name = "json";
            language-servers = withBiome "vscode-json-language-server";
            auto-format = true;
          }
          {
            name = "css";
            language-servers = withBiome "vscode-css-language-server" ++ [ "emmet-ls" ];
            auto-format = true;
          }
          {
            name = "html";
            language-servers = withBiome "vscode-html-language-server" ++ [ "emmet-ls" ];
            auto-format = true;
          }
        ]
        ++
          map
            (name: {
              inherit name;
              language-servers = (withBiome "typescript-language-server");
              auto-format = true;
            })
            [
              "typescript"
              "javascript"
            ]
        ++
          map
            (name: {
              inherit name;
              language-servers = (withBiome "typescript-language-server") ++ [
                "tailwindcss-ls"
                "emmet-ls"
              ];
              auto-format = true;
            })
            [
              "tsx"
              "jsx"
            ];
    };
  };
}
