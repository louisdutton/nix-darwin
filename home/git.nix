{ user, pkgs, ... }:
{
  home.packages = with pkgs; [ glab ];

  programs.lazygit = {
    enable = true;
    settings = {
      keybindings = {
        universal = {
          nextTab = "l";
          prevTab = "h";
          "nextBlock-alt" = false;
          "prevBlock-alt" = false;
        };
      };
    };
  };

  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
  };

  programs.git = {
    enable = true;
    userName = user.displayName;
    userEmail = user.email;
    extraConfig = {
      pull = {
        rebase = false;
      };
      credential = {
        "https://gitlab.com".helper = "!glab auth git-credential";
      };
    };
  };

}
