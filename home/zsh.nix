{ pkgs, ... }:
{
  # automatically init nix shell when entering a relevant directory
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # better cat
  programs.bat.enable = true;

  # better top
  programs.btop = {
    enable = true;
    settings = {
      # theme_background = false;
      vim_keys = true;
    };
  };

  #	better ls
  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    icons = true;
    extraOptions = [
      "--group-directories-first"
      "--header"
    ];
  };

  # better cd
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    options = [ "--cmd cd" ];
  };

  # search utils
  programs.ripgrep.enable = true;
  programs.fd.enable = true;
  programs.fzf =
    let
      fdFile = "fd --type f";
      fdDir = "fd --type d";
    in
    {
      enable = true;
      enableZshIntegration = true;
      defaultCommand = fdFile;
      fileWidgetCommand = fdFile;
      changeDirWidgetCommand = fdDir;
    };

  # better prompt
  programs.starship.enable = true;

  programs.zsh = {
    enable = true;
    autocd = true;
    enableCompletion = true;

    shellAliases = {
      rebuild = "sudo nixos-rebuild switch --flake ~/projects/nixos";
      d = "nix develop --command zsh";
      c = "clear";
      e = "$EDITOR";
      g = "lazygit";
      gl = "glab";
      clean = "git clean -xdf";
      cat = "bat";
      top = "btop";
      sso = "aws sso login --sso-session travelchapter";
      tree = "ls --tree --git-ignore";
      l = "ls -l";
      lsa = "ls -a";
      weather = "xh wttr.in/Truro format==j1 | jq '.current_condition.[0].FeelsLikeC'";
      checkout = "git checkout $(git branch --list | fzf)";
      "-" = "cd -";
    };

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

    initExtra = # bash
      ''
        # vi mode
        bindkey -v
        export KEYTIMEOUT=1

        # viins
        bindkey "^H" backward-delete-char
        bindkey "^?" backward-delete-char
        bindkey '^[^?' backward-kill-word

        # vicmd
        bindkey -M vicmd "H" vi-beginning-of-line
        bindkey -M vicmd "L" vi-end-of-line

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

        # nix shell alias that maps arg -> nixpkgs#arg
        function s() {
        	args=("$@")
        	nix shell ''${args[@]/#/nixpkgs#}
        }

        # take: compound command for mkdir and cd
        function take() {
        	mkdir -p $1
        	cd $1
        }
      '';
    completionInit = # bash
      ''
        autoload -Uz compinit                                   	# autoload completion
        compinit                                                	# initialise completion
        zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'     	# case-insensitive completion
        zstyle ':completion:*' menu select                      	# menu selection
        zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}" # list colors
        bindkey '^[[Z' reverse-menu-complete                    	# shift-tab to navigate backwards
        setopt COMPLETE_IN_WORD
        setopt ALWAYS_TO_END
        setopt MENU_COMPLETE
        setopt COMPLETE_IN_WORD
      '';
  };
}
