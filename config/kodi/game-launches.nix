{pkgs}: {
  # Custom game metadata and independent launch configuration.
  # Store descriptions below are excerpts from the publishers' official copy.
  "custom:fable2" = {
    title = "Fable II";
    details = {
      developers = ["Lionhead Studios"];
      genres = ["Role-playing" "Adventure"];
      game_modes = ["Single player"];
    };
    art = {
      poster = "/home/louis/projects/fable2/assets-extracted/.kodi-art/cover.jpg";
      thumb = "/home/louis/projects/fable2/assets-extracted/.kodi-art/cover.jpg";
    };
    description = "Explore Albion and shape your hero through choices and adventure.";
    workingDirectory = "projects/fable2";
    command = ["${pkgs.devenv}/bin/devenv" "shell" "--" "scripts/play-rev2" "--fullscreen"];
    environment = {
      # Give Kodi's Gamescope hand-off an Xwayland game window to identify.
      SDL_VIDEODRIVER = "x11";
      SDL_GAMECONTROLLER_USE_BUTTON_LABELS = "0";
    };
  };
  "custom:hollie" = {
    title = "Hollie";
    details = {
      developers = ["Louis Dutton"];
      genres = ["Puzzle"];
      game_modes = ["Single player" "Local multiplayer"];
    };
    art = {
      poster = "${./artwork/hollie-cover.png}";
      thumb = "${./artwork/hollie-cover.png}";
      fanart = "${./artwork/hollie-background.png}";
    };
    description = "Explore a world of quiet wonders, follow forgotten paths, and uncover what lies beyond the familiar.";
    workingDirectory = "projects/hollie";
    command = ["${pkgs.devenv}/bin/devenv" "tasks" "run" "hollie:run"];
    environment.SDL_GAMECONTROLLER_USE_BUTTON_LABELS = "0";
  };
  "1030300" = {
    title = "Hollow Knight: Silksong";
    details = {
      developers = ["Team Cherry"];
      publishers = ["Team Cherry"];
      release_date = "2025-09-04";
      genres = ["Action" "Adventure" "Indie"];
      game_modes = ["Single player"];
      metadata_source = "https://store.steampowered.com/app/1030300/";
    };
    description = "Explore, fight and survive as you ascend to the peak of a land ruled by silk and song.";
    descriptionSource = "https://store.steampowered.com/app/1030300/";
    runner = "native";
    executable = "Hollow Knight Silksong";
  };
  "813230" = {
    title = "ANIMAL WELL";
    details = {
      developers = ["Billy Basso"];
      publishers = ["Bigmode"];
      release_date = "2024-05-09";
      genres = ["Action" "Adventure" "Indie"];
      game_modes = ["Single player"];
      metadata_source = "https://store.steampowered.com/app/813230/";
    };
    description = "Explore a dense, interconnected labyrinth, and unravel its many secrets. Collect items to manipulate your environment in surprising and meaningful ways.";
    descriptionSource = "https://store.steampowered.com/app/813230/";
    executable = "Animal Well.exe";
  };
  "367520" = {
    title = "Hollow Knight";
    details = {
      developers = ["Team Cherry"];
      publishers = ["Team Cherry"];
      release_date = "2017-02-24";
      genres = ["Action" "Adventure" "Indie"];
      game_modes = ["Single player"];
      metadata_source = "https://store.steampowered.com/app/367520/";
    };
    description = "Forge your own path in Hollow Knight! An epic action adventure through a vast ruined kingdom of insects and heroes.";
    descriptionSource = "https://store.steampowered.com/app/367520/";
    executable = "hollow_knight.exe";
    prefix = "Games/Prefixes/hollow-knight-standalone";
    saveDirectory = "drive_c/users/steamuser/AppData/LocalLow/Team Cherry/Hollow Knight";
    environment = {
      WINEDLLOVERRIDES = "winhttp=n,b";
    };
  };
}
