{ pkgs, ... }:
{
  programs.nixvim = {
    extraPackages = with pkgs; [
      nixfmt-rfc-style
      prettierd
    ];

    plugins.conform-nvim = {
      enable = true;
      notifyOnError = true;
      formattersByFt = {
        javascript = [ "prettierd" ];
        typescript = [ "prettierd" ];
        json = [ "prettierd" ];
        yaml = [ "prettierd" ];
        nix = [ "nixfmt" ];
      };
      formatOnSave = {
        lspFallback = true;
        timeoutMs = 500;
      };
    };
  };
}
