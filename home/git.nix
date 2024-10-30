{ user, pkgs, ... }:
{
  home.packages = with pkgs; [ glab ];

  programs.lazygit = {
    enable = true;
    settings = {
      gui = {
        mouseEvents = false;
        expandFocusedSidePanel = true;
        showBottomLine = false;
        showRandomTip = false;
        showCommandLog = false;
        showPannelJumps = false;
        border = "hidden";
        filterMode = "fuzzy";
        nerdFontsVersion = 3;
      };

      keybinding = {
        universal = {
          nextTab = "i";
          prevTab = "m";
          scrollLeft = "M";
          scrollRight = "I";
          prevItem-alt = "e";
          nextItem-alt = "n";
          nextBlock-alt = ">";
          prevBlock-alt = "<";
          undo = "u";
          redo = "U";
          nextMatch = "h";
          prevMatch = "H";
          new = "a";
          edit = "E";
          createRebaseOptionsMenu = "^";
        };

        files = {
          ignoreFile = "I";
        };

        branches = {
          viewGitFlowOptions = "I";
        };

        commits = {
          startInteractiveRebase = "I";
        };

        submodules = {
          init = "I";
        };
      };
    };
  };

  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = false;
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
        "https://github.com".helper = "!gh auth git-credential";
      };
    };
  };

}
