{ pkgs, ... }:
{
  programs.nixvim = {
    extraPlugins = with pkgs.vimPlugins; [
      vim-dadbod
      vim-dadbod-completion
    ];
  };
}
