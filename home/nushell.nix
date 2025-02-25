{
  pkgs,
  lib,
  config,
  ...
}:
{
  # automatically init nix shell when entering a relevant directory
  programs.direnv = {
    enable = true;
    enableNushellIntegration = true;
    nix-direnv.enable = true;
    config = {
      hide_env_diff = true;
    };
  };

  # better cd
  programs.zoxide = {
    enable = true;
    enableNushellIntegration = true;
    options = [ "--cmd cd" ];
  };

  # search utils
  programs.ripgrep.enable = true;
  programs.fzf.enable = true;

  programs.nushell = {
    enable = true;
    shellAliases = {
      d = "nix develop --command nu";
      c = "clear";
      e = "hx";
      g = "lazygit";
      gl = "glab";
      clean = "git clean -xdf";
      top = "htop";
      "-" = "cd -";
      l = "ls";
      la = "ls -a";
      ll = "ls -l";
      clip = "pbcopy";
    };

    environmentVariables = {
      # default programs
      # MANPAGER = "nvim +Man!";
      EDITOR = "hx";
      VISUAL = "hx";

      # theme
      LS_COLORS = (import ./lscolors.nix { inherit lib; }) config.lib.stylix.colors;

      # bin
      SHELL = lib.getExe pkgs.nushell;
      PATH = [
        "/Users/louis/.nix-profile/bin"
        "/etc/profiles/per-user/louis/bin"
        "/run/current-system/sw/bin"
        "/nix/var/nix/profiles/default/bin"
        "/usr/local/bin"
        "/usr/bin"
        "/usr/sbin"
        "/bin"
        "/sbin"
      ];

      # nix TODO: dynamic paths based on nix config and curernt generation
      # NIX_PATH = "nixpkgs=/nix/store/csfywra6032psdbgna9qcbdads87gmzw-source";
      # NIX_PROFILES = "/nix/var/nix/profiles/default /run/current-system/sw /etc/profiles/per-user/louis /Users/louis/.nix-profile";
      # NIX_REMOTE = "daemon";
      # NIX_SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
      # NIX_USER_PROFILE_DIR = "/nix/var/nix/profiles/per-user/louis";

      #xdg
      XDG_CONFIG_DIRS = "/Users/louis/.nix-profile/etc/xdg:/etc/profiles/per-user/louis/etc/xdg:/run/current-system/sw/etc/xdg:/nix/var/nix/profiles/default/etc/xdg";
      XDG_DATA_DIRS = "/Users/louis/.nix-profile/share:/etc/profiles/per-user/louis/share:/run/current-system/sw/share:/nix/var/nix/profiles/default/share";

      # darwin
      __NIX_DARWIN_SET_ENVIRONMENT_DONE = "1";
    };

    configFile.text = # nu
      ''
        $env.config.show_banner = false
        $env.config.edit_mode = "vi"
        $env.config.cursor_shape = {
          vi_insert: line
          vi_normal: block
        }
        $env.PROMPT_INDICATOR_VI_INSERT = ""
        $env.PROMPT_INDICATOR_VI_NORMAL = ""

        $env.config.table = {
            mode: rounded # basic, compact, compact_double, light, thin, with_love, rounded, reinforced, heavy, none, other
            index_mode: auto # "always" show indexes, "never" show indexes, "auto" = show indexes when a table has "index" column
            show_empty: true # show 'empty list' and 'empty record' placeholders for command output
            padding: { left: 1, right: 1 } # a left right padding of each column in a table
            trim: {
                methodology: truncating # wrapping or truncating
                wrapping_try_keep_words: true # A strategy used by the 'wrapping' methodology
                truncating_suffix: "..." # A suffix used by the 'truncating' methodology
            }
            header_on_separator: false # show header text on separator/border line
            footer_inheritance: false # render footer in parent table if child is big enough (extended table option)
            # abbreviated_row_count: 10 # limit data rows from top and bottom after reaching a set point
        }

        $env.config.menus = [
          {
            name: completion_menu
            only_buffer_difference: false
            marker: ""
            type: {
              layout: ide
              min_completion_width: 0,
              max_completion_width: 50,
              max_completion_height: 10, # will be limited by the available lines in the terminal
              padding: 0,
              border: false,
              cursor_offset: 0,
              description_mode: "right"
              min_description_width: 0
              max_description_width: 50
              max_description_height: 10
              description_offset: 1
              correct_cursor_pos: false
            }
            style: {
              text: green
              selected_text: { attr: r }
              description_text: yellow
              match_text: { attr: u }
              selected_match_text: { attr: ur }
            }
          }

          # fzf
          {
            name: fzf_file_menu
            only_buffer_difference: true
            marker: "󰱽 "
            type: {
              layout: list
              page_size: 10
            }
            style: {
              text: green
              selected_text: green_reverse
              description_text: yellow
            }
            source: { |buffer, position|
              fd --type f --full-path $env.PWD
              | fzf -f $buffer | lines
              | each { |v| { value: ($v | str trim) }}
            }
          }
          {
            name: fzf_dir_menu
            only_buffer_difference: true
            marker: "󰥩 "
            type: {
              layout: list
              page_size: 10
            }
            style: {
              text: green
              selected_text: green_reverse
              description_text: yellow
            }
            source: { |buffer, position|
              fd --type d --full-path $env.PWD
              | fzf -f $buffer | lines
              | each { |v| { value: ($v | str trim) }}
            }
          }         
        ];

        $env.config.keybindings = [
          {
            name: move_to_line_start
            modifier: shift
            keycode: char_h
            mode: vi_normal
            event: { edit: movetolinestart }
          }
          {
            name: move_to_line_end
            modifier: shift
            keycode: char_l
            mode: vi_normal
            event: { edit: movetolineend }
          }
          {
            name: redo_change
            modifier: shift
            keycode: char_u
            mode: vi_normal
            event: { edit: redo }
          }
          {
            name: delete_line
            modifier: control
            keycode: char_u
            mode: vi_insert
            event: { edit: clear }
          }
          {
            name: delete_word
            modifier: alt
            keycode: backspace
            mode: vi_insert
            event: { edit: backspaceword }
          }

          # fuzzy find
          {
            name: fzf_file_menu
            modifier: control
            keycode: char_t
            mode: [vi_normal, vi_insert]
            event: { send: menu name: fzf_file_menu }
          }
          {
            name: fzf_dir_menu
            modifier: control
            keycode: char_g
            mode: [vi_normal, vi_insert]
            event: { send: menu name: fzf_dir_menu }
          }
        ]
      '';

    extraConfig = # nu
      ''
        def "from png" [] { wezterm imgcat }
        def "from jpg" [] { wezterm imgcat }
        def "from nix" [] { nix eval --expr $in | from json }

        def lunch [] {
          http post -t application/json -H {Authorization: $"Bearer ($env.SLACK_TOKEN)"} https://slack.com/api/users.profile.set {
            profile: {
              status_test: "lunch",
              status_emoji: ":ramen:",
              status_expiration: (date now | into int)
            }
          }
        }
      '';
  };
}
