{ pkgs, ... }:
{
  programs.git = {
    enable = true;
    userEmail = "louis.dutton@icloud.com";
    userName = "Louis Dutton";
    ignores = [
      ".DS_Store"
    ];
    extraConfig = {
      init.defaultBranch = "main";
    };
  };
}
