{user, ...}: {
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
    };
  };
}
