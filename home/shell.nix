{ pkgs, lib, ... }:
{
  # shell
  home.shell.enableZshIntegration = true;
  home.shell.enableNushellIntegration = true;
  programs.zsh = {
    enable = true;
    enableCompletion = true;
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

    initExtra = # zsh
      ''
        # vi mode
        bindkey -v
        export KEYTIMEOUT=1

        # viins
        bindkey "^H" backward-delete-char
        bindkey "^?" backward-delete-char
        bindkey '^[^?' backward-kill-word

        # vicmd
        bindkey -M vicmd h backward-char
        bindkey -M vicmd j down-line-or-history
        bindkey -M vicmd k up-line-or-history
        bindkey -M vicmd l forward-char
        bindkey -M vicmd H vi-beginning-of-line
        bindkey -M vicmd L vi-end-of-line
        bindkey -M vicmd i vi-insert
        bindkey -M vicmd I vi-insert-bol
        bindkey -M vicmd n vi-repeat-search
        bindkey -M vicmd N vi-rev-repeat-search
        bindkey -M vicmd u undo
        bindkey -M vicmd U redo

        # completion
        bindkey '^[[Z' reverse-menu-complete # shift-tab to focus previous comp option

        # Change cursor shape for different vi modes.
        function zle-keymap-select {
        	if [[ $KEYMAP == vicmd ]] ||
        		 [[ $1 = "block" ]]; then
        		echo -ne "\e[1 q"
        	elif [[ $KEYMAP == main ]] ||
        			 [[ KEYMAP == viins ]] ||
        			 [[ KEYMAP = "" ]] ||
        			 [[ $1 = "beam" ]]; then
        		echo -ne "\e[5 q"
        	fi
        }
        zle -N zle-keymap-select
        zle-line-init() {
        		zle -K viins # initiate `vi insert` as keymap (can be removed if `bindkey -V` has been set elsewhere)
        		echo -ne "\e[5 q"
        }
        zle -N zle-line-init
        echo -ne "\e[5 q" # Use beam shape cursor on startup.
        preexec() { echo -ne "\e[5 q" ;} # Use beam shape cursor for each new prompt.

        # take: compound mkdir && cd
        function take() {
        	mkdir -p $1
        	cd $1
        }
      '';

    completionInit = # zsh
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
        setopt COMPLETE_IN_WORD
      '';
  };

  # automatically init nix shell when entering a relevant directory
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    config = {
      hide_env_diff = true;
    };
  };

  # better cd
  programs.zoxide = {
    enable = true;
    options = [ "--cmd cd" ];
  };

  # better ls
  programs.eza.enable = true;

  # better grep
  programs.ripgrep.enable = true;

  # fuzzy find
  programs.fzf = {
    enable = true;
    colors.bg = lib.mkForce "-1"; # transparent
    fileWidgetCommand = "fd --type f";
    changeDirWidgetCommand = "fd --type d";
    defaultOptions = [
      "--reverse"
      "--style minimal"
      "--bind tab:down,shift-tab:up"
    ];
  };

  # data querying and manipulation
  programs.nushell.enable = true;
}
