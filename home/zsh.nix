{ pkgs, keymap, ... }:
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
  programs.htop.enable = true;

  #	better ls
  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    icons = "auto";
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

  # remove init messaage
  home.file.".hushlogin".text = "";

  programs.zsh = {
    enable = true;
    autocd = true;
    enableCompletion = true;

    shellAliases = {
      d = "nix develop --command zsh";
      c = "clear";
      e = "$EDITOR";
      g = "lazygit";
      gl = "glab";
      clean = "git clean -xdf";
      cat = "bat";
      top = "htop";
      tree = "ls --tree --git-ignore";
      l = "ls -l";
      la = "ls -la";
      lsa = "ls -a";
      "-" = "cd -";
      clip = "pbcopy";
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

    initExtra =
      with keymap; # bash
      ''
        # vi mode
        bindkey -v
        export KEYTIMEOUT=1

        # viins
        bindkey "^H" backward-delete-char
        bindkey "^?" backward-delete-char
        bindkey '^[^?' backward-kill-word

        # vicmd
        bindkey -M vicmd "${left}" backward-char
        bindkey -M vicmd "${down}" down-line-or-history
        bindkey -M vicmd "${up}" up-line-or-history
        bindkey -M vicmd "${right}" forward-char
        bindkey -M vicmd "${farleft}" vi-beginning-of-line
        bindkey -M vicmd "${farright}" vi-end-of-line

        bindkey -M vicmd "${insert}" vi-insert
        bindkey -M vicmd "${farinsert}" vi-insert-bol
        bindkey -M vicmd "${next}" vi-repeat-search
        bindkey -M vicmd "${prev}" vi-rev-repeat-search

        bindkey -M vicmd "${undo}" undo
        bindkey -M vicmd "${redo}" redo

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

        bindkey '^[[Z' reverse-menu-complete # shift-tab to focus previous comp option
      '';
  };
}
