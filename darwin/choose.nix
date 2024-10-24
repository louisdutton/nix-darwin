{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [ choose-gui ];
  environment.shellAliases = {
    choose-app = # shell
      ''
        ls /Applications/ /Applications/Utilities/ /System/Applications/ /System/Applications/Utilities/ | \
            rg '\.app$' | \
            sed 's/\.app$//g' | \
            choose | \
            xargs -I {} open -a "{}.app"
      '';
  };
}
