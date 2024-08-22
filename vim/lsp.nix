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
        tsserver.enable = true;
        eslint.enable = true;
        html.enable = true;
        lemminx.enable = true;
        java-language-server.enable = true;
        kotlin-language-server.enable = true;
        jsonls.enable = true;
        yamlls.enable = true;
        taplo.enable = true;
        gopls.enable = true;
        clangd.enable = true;

        nil-ls = {
          enable = true;
          settings.nix = {
            flake.autoEvalInputs = false; # runs out of memory
            maxMemoryMB = null;
          };
        };

        rust-analyzer = {
          enable = true;
          installCargo = false;
          installRustc = false;
        };
      };
    };
  };
}
