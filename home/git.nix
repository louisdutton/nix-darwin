{
  user,
  pkgs,
  keymap,
  ...
}:
{
  home.packages = with pkgs; [ glab ];

  programs.lazygit = {
    enable = true;
    settings = {
      git.paging = {
        colorArg = "always";
        pager = "delta --paging=never --side-by-side";
      };
      gui = {
        mouseEvents = false;
        expandFocusedSidePanel = true;
        showBottomLine = false;
        showRandomTip = false;
        showCommandLog = false;
        showPannelJumps = false;
        border = "rounded";
        filterMode = "fuzzy";
        nerdFontsVersion = 3;
      };

      keybinding = with keymap; {
        universal = {
          nextBlock = right;
          prevBlock = left;
          nextTab = farright;
          prevTab = farleft;
          nextMatch = next;
          prevMatch = prev;
          prevItem = up;
          nextItem = down;
          undo = undo;
          redo = redo;
        };

        files = {
          ignoreFile = "i";
        };

        branches = {
          viewGitFlowOptions = "i";
        };

        commits = {
          startInteractiveRebase = "i";
        };

        submodules = {
          init = "i";
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

    delta = {
      enable = true;
      options = {
        dark = true;
        syntax-theme = "base16-stylix";
      };
    };
  };
}
