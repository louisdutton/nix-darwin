{ pkgs, ... }:
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

        # nix
        nil_ls = {
          enable = true;
          settings.nix = {
            flake.autoEvalInputs = false; # runs out of memory
            maxMemoryMB = null;
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
