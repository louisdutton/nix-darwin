{ ... }:
{
  programs.nixvim.plugins = {
    lspkind = {
      enable = true;
      cmp.enable = true;
    };

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

        # nix
        nixd = {
          enable = true;
          settings.options = {
            nixos.expr = "(builtins.getFlake \"/Users/louis/.config/nix-darwin\").darwinConfigurations.nixos.options";
            # home-manager.expr = "(builtins.getFlake \"/Users/louis/.config/nix-darwin\").nixosConfigurations.nixos.options"
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
