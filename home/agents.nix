{pkgs, ...}: {
  programs.zsh.shellAliases."?" = "claude";

  programs.mcp = {
    enable = true;
    servers = {
      playwright = {
        command = "${pkgs.playwright-mcp}/bin/mcp-server-playwright";
        args = ["--headless"];
      };
      ms365 = {
        command = "${pkgs.bun}/bin/bunx";
        args = ["-y" "@softeria/ms-365-mcp-server"];
      };
    };
  };

  programs.claude-code = {
    enable = true;
    enableMcpIntegration = true;
    package = pkgs.writeShellScriptBin "claude" ''
      export SHELL=${pkgs.bash}/bin/bash
      exec ${pkgs.claude-code}/bin/claude --dangerously-skip-permissions "$@"
    '';
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
