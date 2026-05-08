{
  pkgs,
  lib,
  config,
  ...
}: {
  home.shell.enableZshIntegration = true;
  home.shell.enableNushellIntegration = true;
  home.packages = with pkgs; [
    sd # better sed
    fd # better find
    xh # better curl
    fx # json query (alternative to jq)
  ];

  programs = {
    zsh = {
      enable = true;
      enableCompletion = true;
      dotDir = config.home.homeDirectory;
      autocd = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;

      plugins = [
        {
          name = "zsh-system-clipboard";
          src = pkgs.fetchFromGitHub {
            owner = "kutsan";
            repo = "zsh-system-clipboard";
            rev = "v0.8.0";
            sha256 = "VWTEJGudlQlNwLOUfpo0fvh0MyA2DqV+aieNPx/WzSI=";
          };
        }
      ];

      initContent =
        # zsh
        ''
          # take: compound mkdir && cd
          function take() {
          	mkdir -p $1
          	cd $1
          }
        '';

      completionInit =
        # zsh
        ''
          autoload -Uz compinit
          compinit

          zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}' # case-insensitive completion
          zstyle ':completion:*' menu select
          zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"
          zstyle ':completion:*:-command-:*' tag-order '!parameters' # rm env vars from cmd completion

          setopt COMPLETE_IN_WORD
          setopt ALWAYS_TO_END
          setopt MENU_COMPLETE
        '';
    };

    # automatically init nix shell when entering a relevant directory
    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
      config = {
        hide_env_diff = true;
      };
    };

    # better cd
    zoxide = {
      enable = true;
      options = ["--cmd cd"];
    };

    # better cat
    bat.enable = true;
    zsh.shellAliases.cat = "bat";

    # better ls
    eza.enable = true;

    # better grep
    ripgrep = {
      enable = true;
      arguments = [
        "--smart-case"
      ];
    };

    # better top
    btop = {
      enable = true;
    };
    zsh.shellAliases.top = "btop";

    # fuzzy find
    fzf = {
      enable = true;
      colors.bg = lib.mkForce "-1"; # transparent
      fileWidgetCommand = "fd --type f";
      changeDirWidgetCommand = "fd --type d";
      defaultOptions = [
        "--reverse"
        "--style minimal"
      ];
    };
  };
}
