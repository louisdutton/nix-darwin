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
          lsp_format = "first";
          timeout_ms = 500;
        };
      };
    };
  };
}
