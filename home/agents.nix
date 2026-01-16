{pkgs, ...}: {
  programs.claude-code = {
    enable = true;
    settings = {
      includeCoAuthoredBy = false;
    };

    skills = {
      code-analysis = ''
        ---
        name: code-analysis
        description: Extract information about a codebase using special cli tools
        allowed-tools: Bash(fd), Bash(rg)
        ---

        # Code analysis

        ## Files (instead of find)
        Use the `fd` cli to find files recursively within the CWD

        ## Texts (instead of grep)
        Use the `rg` cli to find excerpts recursively within the CWD
      '';
    };
  };
}
