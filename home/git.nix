{
  user,
  keymap,
  ...
}:
{
  programs.lazygit = {
    enable = true;
    settings = {
      gui = {
        mouseEvents = false;
        expandFocusedSidePanel = false;
        showListFooter = false;
        showBottomLine = false;
        showRandomTip = false;
        showCommandLog = false;
        showPannelJumps = false;
        border = "rounded";
        filterMode = "fuzzy";
        nerdFontsVersion = 3;
      };

      # reduce prompting
      disableStartupPopups = true;
      notARepository = "quit";
      promptToReturnFromSubprocess = false;

      keybinding = with keymap; {
        universal = {
          nextBlock = right;
          prevBlock = left;
          # nextTab = farright;
          # prevTab = farleft;
          nextMatchAlt = next;
          prevMatchAlt = prev;
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
