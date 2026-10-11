# GOG without Heroic

`hosts/theatre/default.nix` packages `gog` and `gogdl`. Kodi's launch tools
pin UMU and `proton-ge-bin.steamcompattool` through the existing nixpkgs lock.
There are no runtime Proton downloads from Heroic; UMU's separate compatibility
runtime remains UMU-managed. Updating Proton means updating/rebuilding Nix.

```sh
gog list                       # Live owned library with installation status
gog list --uninstalled
gog list --installed
gog list --offline             # Previously fetched account inventory
gog list --json
gog info GAME_ID               # Download/disk estimates and destination free space
gog artwork                    # Cache missing GOG portrait covers, offline inventory
gog install GAME_ID            # Windows build, ~/Games/GOG/GAME_ID
gog install GAME_ID --path /absolute/game/directory --platform linux
gog update GAME_ID
gog repair GAME_ID
gog uninstall GAME_ID          # Recoverable removal; does NOT free disk space
gog import /absolute/existing/game/directory
gogdl --help                   # Lower-level downloader/cloud-save commands
```

Installation/update/repair registers successful installations automatically.
Registration detects GOG metadata in the download root or up to two nested
directories. Launches use the actual game directory; update/repair retain the
original download root so wrapped layouts are not downloaded into themselves.
Update/repair also preserve the registered executable, arguments, environment,
working directory and prefix, including explicitly empty launch settings.
Ambiguous installations and metadata symlinks escaping the download are refused.
New Windows games receive independent `~/Games/Prefixes/gog-GAME_ID` prefixes.
Actual Wine/Proton versions are selected by Kodi's Nix-generated launch tools,
not by writable game metadata. New native Linux installs require their GOG
`start.sh`; updates and repairs retain the registered native executable.
`gog import` currently supports Windows installations with GOG `.info` metadata.

`gog migrate-heroic` copies authentication, cached artwork and installed metadata
without moving/deleting originals. It preserves existing prefix and custom
executable paths. `--refresh` explicitly re-imports existing launch preferences.
The initial theatre migration imports only the three directories still present,
not the stale removed entries in Heroic's installed file.

Credentials live privately in `~/.config/gog/auth.json`, never in Nix or Git.
`gog login` handles browser authorization and suppresses the downloader's token
output. Avoid sharing raw `gogdl auth` output: upstream prints credentials.
Owned-library listing talks to GOG's authenticated account endpoint with
pagination; it is independent of Heroic's cached library. Playing is offline
and does not perform cloud synchronization automatically.

Installation metadata and account inventory live in `~/.local/share/gog/`.
These paths respect XDG config/data overrides in the CLI; theatre Kodi currently
uses the standard data path. Kodi's Games row includes owned, uninstalled GOG
games with dimmed labels. Selecting one offers installation confirmation;
uninstalled portraits are also dimmed, including when focused. Library refresh
caches missing portrait covers directly from GOG, independently of Heroic.
Artwork refresh also caches GOG's full background images (falling back to wide
artwork if unavailable), even when a portrait was already cached. Kodi fits the
complete backdrop without cropping or animated zoom, preserving aspect ratio.
Wide banners dock at the screen's top edge and fade vertically into the theme
background. The rails' vertical scrolling viewport reaches both screen edges,
rather than clipping rows inside the theme's former menu/header gutters.
installed GOG games have an Uninstall context-menu action. The row also offers
an explicit owned-library refresh (normal browsing remains offline).

Kodi calls the same Nix-pinned CLI, with a cancellable progress dialog and owned
systemd process group. Cancelling an install stops all download descendants;
installation confirmation shows full-download/installed estimates and free
space on the destination filesystem (retries may need less). Insufficient game
space blocks installation; limited temporary-file/prefix headroom warns.
During download the CLI writes a private, atomic numeric status snapshot for
Kodi: written-byte percentage, transferred bytes, transfer speed and ETA. Kodi
never displays raw network logs. ETA is unknown until progress begins, and
registration is a separate finishing stage before success/100%.
partial files remain for a retry. CLI mutations are serialized. Installation
defaults to Windows builds with the Nix-managed Proton runner.

Uninstall moves the validated dedicated installation directory into
`~/.local/share/gog/removed/ID-UUID/files`, with original metadata in
`record.json`. This preserves unknown saves inside game directories as well as
external prefixes. **It does not reclaim disk space.** Recovery files are not
automatically purged. No binaries or uninstaller scripts are executed. Removal
refuses paths outside dedicated directories beneath `~/Games`, overlapping
installations, symlinks, or directories containing the Wine prefix.
