{ pkgs, ... }:
{
  programs.nixvim = {
    extraPackages = with pkgs; [
      nixfmt-rfc-style
      prettierd
    ];

    plugins.conform-nvim = {
      enable = true;
      settings = {
        notify_on_error = true;
        format_on_save = {
          lspFallback = true;
          timeoutMs = 500;
        };
        formatters_by_ft = {
          javascript = [ "prettierd" ];
          typescript = [ "prettierd" ];
          json = [ "prettierd" ];
          yaml = [ "prettierd" ];
          nix = [ "nixfmt" ];
        };
      };
    };
  };
}
