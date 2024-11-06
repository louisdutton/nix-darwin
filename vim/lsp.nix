{ self, ... }:
{
  programs.nixvim.plugins = {
    lspkind = {
      enable = true;
      cmp.enable = true;
    };

    lsp-lines.enable = true;
    lsp-signature.enable = true;

    lsp = {
      enable = true;
      servers = {
        ts_ls.enable = true;
        eslint.enable = true;
        html.enable = true;
        lemminx.enable = true;
        jsonls.enable = true;
        yamlls.enable = true;
        taplo.enable = true; # toml
        gopls.enable = true;
        clangd.enable = true;
        cssls.enable = true;
        ols.enable = true;

        # nix
        nixd = {
          enable = true;
          settings.options =
            let
              # system = ''''${builtins.currentSystem)}'';
              flake = ''builtins.getFlake "${self}")'';
            in
            rec {
              nixos.expr = "${flake}.darwinConfigurations.nixos.options";
              home-manager.expr = "${nixos.expr}.home-manager.users.type.getSubOptions [ ]";
            };
        };

        # rust
        rust_analyzer = {
          enable = true;
          installCargo = false;
          installRustc = false;
        };
      };
    };
  };
}
