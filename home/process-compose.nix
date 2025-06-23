{
  home.file.".config/process-compose/settings.yaml".text =
    # yaml
    ''
      disable_exit_confirmation: false
    '';

  home.file.".config/process-compose/shortcuts.yaml".text =
    # yaml
    ''
      shortcuts:
        process_restart: { shortcut: r }
        process_screen: { shortcut: f }
        process_start: { shortcut: Return }
        process_stop: { shortcut: d }
        proc_filter: { shortcut: '?' }
        find: { shortcut: / }
        find_prev: { shortcut: N }
        find_next: { shortcut: n }
        find_exit: { shortcut: Escape }
        quit: { shortcut: q }
    '';
}
