{pkgs}: {
  # Custom game metadata and independent launch configuration.
  # Store descriptions below are excerpts from the publishers' official copy.
  "custom:hollie" = {
    title = "Hollie";
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
    description = "Explore, fight and survive as you ascend to the peak of a land ruled by silk and song.";
    descriptionSource = "https://store.steampowered.com/app/1030300/";
    runner = "native";
    executable = "Hollow Knight Silksong";
  };
  "813230" = {
    title = "ANIMAL WELL";
    description = "Explore a dense, interconnected labyrinth, and unravel its many secrets. Collect items to manipulate your environment in surprising and meaningful ways.";
    descriptionSource = "https://store.steampowered.com/app/813230/";
    executable = "Animal Well.exe";
  };
  "367520" = {
    title = "Hollow Knight";
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
