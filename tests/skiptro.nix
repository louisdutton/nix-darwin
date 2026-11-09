{
  pkgs,
  nixpkgs,
  package ? import ../pkgs/skiptro {inherit pkgs;},
}: let
  fakeScanner = pkgs.writeShellScriptBin "skiptro" ''
    exec ${pkgs.python3}/bin/python3 - "$@" <<'PY'
    import json
    import os
    import pathlib
    import sys

    with open(os.environ["SKIPTRO_COMMAND_LOG"], "a") as log:
        log.write(json.dumps(sys.argv[1:]) + "\n")
    known = pathlib.Path("scanned-roots.json")
    roots = json.loads(known.read_text()) if known.exists() else []
    # Upstream cannot configure a show's window until a scan discovers it.
    if sys.argv[1:3] == ["show", "window"]:
        if not any(sys.argv[3].startswith(root) for root in roots):
            sys.exit(1)
    if sys.argv[1] == "scan":
        if os.environ.get("SKIPTRO_FAIL_SCAN"):
            sys.exit(7)
        known.write_text(json.dumps(sorted(set(roots + [sys.argv[2]]))))
    PY
  '';
  libraries = ["/media/TV Shows" "/media/TV Shows-Other/"];
  initialPolicy = {
    "/media/TV Shows/A Show (2026)" = 5;
    "/media/TV Shows/Removed Show (2026)" = 5;
  };
  changedPolicy = {"/media/TV Shows/A Show (2026)" = 4;};
  retryPolicy = {"/media/TV Shows/A Show (2026)" = 3;};
  serviceScript = searchWindows:
    (nixpkgs.lib.nixosSystem {
      system = pkgs.stdenv.hostPlatform.system;
      modules = [
        ../modules/skiptro.nix
        {
          services.skiptro = {
            enable = true;
            package = fakeScanner;
            user = "root";
            inherit libraries searchWindows;
          };
          system.stateVersion = "26.05";
        }
      ];
    }).config.systemd.services.skiptro-scan.serviceConfig.ExecStart;
  moduleFixtures = pkgs.writeText "skiptro-module-fixtures.json" (builtins.toJSON {
    inherit libraries initialPolicy changedPolicy retryPolicy;
    scripts = map serviceScript [initialPolicy changedPolicy retryPolicy];
  });
in
  pkgs.runCommand "skiptro-edl-check" {
    nativeBuildInputs = [package pkgs.python3];
  } ''
    export HOME="$TMPDIR/home"
    export XDG_CONFIG_HOME="$TMPDIR/config"
    mkdir -p "$HOME" "$XDG_CONFIG_HOME"
    python3 - <<'PY'
    import os
    import pathlib
    import sqlite3
    import subprocess

    def run(*args):
        return subprocess.run(
            ["skiptro", *args], check=True, capture_output=True, text=True
        )

    # Let the packaged application create its actual schema, including native SQLite.
    run("status")
    database = pathlib.Path(os.environ["XDG_CONFIG_HOME"]) / "Skiptro/skiptro.db"
    connection = sqlite3.connect(database)
    roots = [pathlib.Path.cwd() / "TV Shows", pathlib.Path.cwd() / "TV Shows-Other"]
    files = []
    for library_id, root in enumerate(roots, 1):
        episode = root / "A Show/Season 1/A Show.S01E01.mkv"
        episode.parent.mkdir(parents=True)
        episode.touch()
        files.append(episode)
        connection.execute(
            "INSERT INTO MediaLibraries (Id,Name,Path,CreatedAt) VALUES (?,?,?,?)",
            (library_id, root.name, str(root), "2026-10-16T00:00:00Z"),
        )
        # Intro = 0, credits = 1. Only intros should become automatic skip ranges.
        for segment_type, start, end in [(0, 12.5, 32.5), (1, 80.0, 90.0)]:
            connection.execute(
                """INSERT INTO DetectedSegments (
                    LibraryId,FilePath,ShowName,Season,Episode,Type,
                    StartSeconds,EndSeconds,Confidence,DetectedAt,FileModifiedAt
                ) VALUES (?,?,?,?,?,?,?,?,?,?,?)""",
                (library_id, str(episode), "A Show", 1, 1, segment_type,
                 start, end, 1.0, "2026-10-16T00:00:00Z", "2026-10-16T00:00:00Z"),
            )
    connection.commit()
    connection.close()

    unrelated = files[1].with_suffix(".edl")
    unrelated.write_text("unrelated existing sidecar\n")
    # The CLI filters by string prefix, so the directory separator is significant.
    run("export-edl", str(roots[0]) + "/")
    sidecar = files[0].with_suffix(".edl")
    assert sidecar.read_text() == "12.5\t32.5\t3\n", sidecar.read_text()
    assert unrelated.read_text() == "unrelated existing sidecar\n"
    assert list(roots[0].rglob("*.edl")) == [sidecar]
    assert not list(roots[0].rglob("*.skiptro.json"))
    PY

    python3 - ${moduleFixtures} <<'PY'
    import json
    import os
    import pathlib
    import shlex
    import subprocess
    import sys

    fixtures = json.loads(pathlib.Path(sys.argv[1]).read_text())
    state = pathlib.Path.cwd() / "module-state"
    state.mkdir()
    log = state / "commands.jsonl"
    checkpoint = state / "search-windows.json"
    # The real service has no broad development-tool PATH. Keep dependencies
    # explicit, so a missing cmp or jq cannot turn every scan into a forced one.
    environment = os.environ | {
        "SKIPTRO_COMMAND_LOG": str(log),
        "PATH": "${pkgs.coreutils}/bin",
    }
    roots = [root.rstrip("/") + "/" for root in fixtures["libraries"]]

    def run(script, *, fail=False):
        log.write_text("")
        env = environment | ({"SKIPTRO_FAIL_SCAN": "1"} if fail else {})
        result = subprocess.run(shlex.split(script), cwd=state, env=env, capture_output=True, text=True)
        assert result.returncode == (7 if fail else 0), result.stderr
        return [json.loads(line) for line in log.read_text().splitlines()]

    def policy_commands(policy, reset=False):
        return [
            ["show", "window", show, "default" if reset else str(minutes)]
            for show, minutes in sorted(policy.items())
        ]

    def library_commands(force):
        return [command for root in roots for command in [
            ["scan", root] + (["--force"] if force else []),
            ["export-edl", root],
        ]]

    initial = fixtures["initialPolicy"]
    changed = fixtures["changedPolicy"]
    retry = fixtures["retryPolicy"]
    first_script, changed_script, retry_script = fixtures["scripts"]
    bootstrap = [["scan", root] for root in roots]

    # Execute the module's actual generated ExecStart, retaining its set -e behavior.
    # Paths with spaces must remain single arguments; every export root ends in /.
    assert run(first_script) == bootstrap + policy_commands(initial) + library_commands(True)
    assert json.loads(checkpoint.read_text()) == initial
    assert run(first_script) == policy_commands(initial) + library_commands(False)

    # Policy changes invalidate cached detections and remove retired show overrides.
    assert run(changed_script) == (
        bootstrap + policy_commands(initial, reset=True)
        + policy_commands(changed) + library_commands(True)
    )
    assert json.loads(checkpoint.read_text()) == changed

    # An unsuccessful scan must not export or mark its policy as applied.
    assert run(retry_script, fail=True) == [["scan", roots[0]]]
    assert json.loads(checkpoint.read_text()) == changed
    assert run(retry_script) == (
        bootstrap + policy_commands(changed, reset=True)
        + policy_commands(retry) + library_commands(True)
    )
    assert json.loads(checkpoint.read_text()) == retry
    PY
    touch "$out"
  ''
