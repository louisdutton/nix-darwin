{ self, ... }:
{
  # detailed diagnostics for the current line via virtual lines
  programs.nixvim.plugins.lsp-lines.enable = true;
  programs.nixvim.diagnostics = {
    virtual_lines = {
      only_current_line = true;
    };
    virtual_text = false;
  };

  programs.nixvim.plugins = {
    # show lsp sources
    lspkind = {
      enable = true;
      cmp.enable = true;
    };

    # show docs whilst filling out params
    lsp-signature.enable = true;

    # include lsp info in the status bar
    lsp-status = {
      enable = true;
    };

    # disable semantic token provider in favour of treesitter
    lsp.onAttach = # lua
      ''
        client.server_capabilities.semanticTokensProvider = nil
      '';

    lsp = {
      enable = true;
      servers = {
        # config / docs
        jsonls.enable = true;
        yamlls.enable = true;
        taplo.enable = true; # toml
        lemminx.enable = true; # xml
        marksman.enable = true;

        # webdev
        ts_ls.enable = true;
        eslint.enable = true;
        html.enable = true;
        cssls.enable = true;

        # proper languages
        gopls.enable = true;
        clangd.enable = true; # c/c++
        ols.enable = true; # xml

        # nix
        nixd = {
          enable = true;
          settings.options =
            let
              # system = ''''${builtins.currentSystem)}'';
              flake = ''(builtins.getFlake "${self}")'';
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
