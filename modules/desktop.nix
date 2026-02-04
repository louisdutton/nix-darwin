{
  user,
  pkgs,
  ...
}: {
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  services.getty.autologinUser = user.name;

  programs.zsh.loginShellInit = ''
    if [[ -z "$WAYLAND_DISPLAY" ]] && [[ $(tty) == /dev/tty1 ]]; then
      uwsm start -D Hyprland -- start-hyprland
    fi
  '';

  # audio
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # configure policies (not the actual package) for chromium-based browsers
  # the browser package itself is managed by home-manager
  programs.chromium = {
    enable = true;
    defaultSearchProviderEnabled = true;
    defaultSearchProviderSearchURL = "https://www.startpage.com/sp/search?query={searchTerms}";
    defaultSearchProviderSuggestURL = "https://www.startpage.com/osuggestions?q=%s{searchTerms}";
    extraOpts = {
      "BrowserSignin" = 0;
      "SyncDisabled" = false;
      "PasswordManagerEnabled" = false;
      "SpellcheckEnabled" = true;
      "SpellcheckLanguage" = [
        "en-GB"
      ];
    };

    # this doesn't work for ungoogled-chromium
    # in that case, the exts but be fetched as part of the home-manager config
    # extensions = [
    #   "ghmbeldphafepmbegfdlkpapadhbakde" # proton-pass
    #   "gfbliohnnapiefjpjlpjnehglfpaknnc" # surfing keys
    # ];
  };

  environment = {
    systemPackages = with pkgs; [
      pamixer
      playerctl
    ];
  };
}
