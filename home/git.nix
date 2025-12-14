{
  user,
  keymap,
  ...
}: {
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
        showPanelJumps = false;
        border = "rounded";
        filterMode = "fuzzy";
        nerdFontsVersion = "3";
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
          # nextMatchAlt = next;
          # prevMatchAlt = prev;
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
    settings = {
      user = {
        name = user.displayName;
        email = user.email;
      };

      pull = {
        rebase = true;
      };
      credential = {
        "https://github.com".helper = "!gh auth git-credential";
      };
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      dark = true;
      syntax-theme = "base16-stylix";
    };
  };
}
