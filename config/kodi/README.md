# Theatre Kodi

System configuration: `hosts/theatre/default.nix` selects native Wayland Kodi
inside Gamescope as the default SDDM session, and retains Steam/Gamescope as
an alternative.
`pkgs/kodi` builds the shared package used by the system and Home Manager.
The entrypoints own a transient user service with `KillMode=control-group`.
An owner pidfd guardian ends every descendant if the session wrapper dies;
the wrapper also exits when its SDDM parent dies. A runtime lock rejects a
second production instance. Private profiles have separate service names.
Smoke tests explicitly stop their entire named scope, not just systemd-run.

Kodi is pinned to 22.0rc1 (Piers), including the upstream native PipeWire
HDMI-device-change deadlock fix. Matching joystick support is pinned and rebuilt
against the same Kodi. This is a release candidate, not a stable release.
`pkgs/kodi/core.nix` can be removed when nixpkgs ships a fixed Piers release.
The package selects `--audio-backend=pipewire` and the default PipeWire device so
HDMI disappearance/reappearance can be handled by the audio backend.
Before launch, a bounded PipeWire IPC check fails with a diagnostic rather than
starting Kodi without an audio backend. It does not require the TV to be on.
Before each version change, preparation copies the entire userdata profile
to `.kodi/nix-backups/<timestamp>/pre-upgrade-userdata`; restore it with Kodi
stopped if rolling back to an older major version.

`tv on|off|status|cycle|adapters` controls TV standby/wake through libCEC.
This requires a supported CEC adapter; the current GPU exposes none. `cycle`
means five seconds in standby followed by wake, not a mains-power reset.
Kodi's bundled CEC default is disabled so it does not claim the adapter from
the CLI (or automatically turn the TV off when Kodi exits). Manually enabling
Kodi's CEC remote input would conflict with these CLI commands.

Home Manager's `programs.kodi` module manages media sources, advanced settings,
and ordinary add-on settings. `home/kodi.nix` also manages the gamepad keymap
and the 14-button Linux Pro Controller map. The Kodi startup splash is disabled.

## Where to change things

The [`skin.theatre`](skin.theatre/) fork has a fixed Home
layout and native playback/dialogs without runtime menu generation.
`skin.theatre` is the sole production skin.
`nix run .#theatre-kodi-preview` uses its own preview profile.

- `preferences.nix`: owned GUI settings, advanced settings and add-on settings.
- `skin.theatre/1080i/`: the Home layout, native views and playback controls.
  Continue is docked at the bottom beneath Home/Videos/Games navigation.
  Settings and Power remain accessible through controller shortcuts.
- `Pro_Controller_14b_6a.xml`: Nintendo A selects, B goes back; D-pad and sticks
  navigate. Retained native-Kodi fallback; normal controller input is now
  owned by InputPlumber, with Kodi's joystick handling disabled.
- `inputplumber.nix`: declarative Pro Controller capture and stable
  Xbox-compatible virtual gamepad/keyboard targets. Kodi gets navigation keys;
  games get letter-matched gamepad input. Home opens Power in Kodi (F7); the game profile retains its session shortcut (F13).
  The local `modules/inputplumber.nix` extends nixpkgs' module with devices,
  profiles and capability maps with nested Nix submodules and enums defined in
  `modules/inputplumber/types.nix`. Invalid fields,
  missing required settings and unsupported event enums fail during evaluation;
  the module generates YAML without a Python validator. Theatre turns
  off bundled device definitions and selects Kodi as the default profile;
  runtime profiles live under `/etc/inputplumber/profiles.d/`.
  `options.auto_manage=true` is required: matching a controller does not by
  itself capture it. Native Kodi input stays enabled as a bootstrap/fallback
  until the routing service detects and configures a managed controller.
- `gamepad.xml`: + opens Settings, Home opens Power, and X opens context options.
  InputPlumber emits F6/F7 for +/Home to avoid the application-launch keysyms
  assigned to Linux F14/F15 by the keyboard layout. On Home, B focuses the visible content, and
  holding B opens Power. During full-screen video, A directly toggles pause
  (Y also works), and left/right scrub using Kodi's native progressive seek
  steps. Up/down or X opens the compact bottom bar: Audio, Subtitles and
  Episodes (Back for films), navigated vertically; left/right still scrub.
  There are no redundant play/pause or skip buttons. B dismisses
  controls first, then stops playback and opens the show's native episode list,
  even after launching from Continue. Films return to their original screen.
  Controls auto-hide after five idle seconds except while paused or in a
  subdialog. `localhome/video_controls.py` reads the playing episode's native
  database ID before stopping; Kodi still owns all resume/watch state.
  Continue opens game details or the native episode list with the relevant
  episode highlighted; playback starts only after selecting it there. Back from that playback only
  stops the player: no Home detour, widget waiting or duplicate list reload.
  Entering Home through any route
  also stops video. Refresh-rate adjustment uses Always: native video cadence
  full-screen, and the desktop refresh rate for the interface.
- `localhome/`: local media, independent Steam-library and GOG games, cached
  artwork, controller routing and library scan at startup.

Theatre is packaged directly from this repository by `pkgs/kodi/skin.nix`.
It requires no upstream skin helpers or generated menus. Kodi add-on updates
are disabled; skin changes are reviewed here and rebuilt with Nix.

## Writable state and migration

Home has a fixed screen layout: Home, Videos and Games form the top
navigation, and Continue is docked at the bottom. With no activity history,
Continue is hidden and navigation remains usable. Videos and Games use
resident caption-free portrait panels (controls 30121 and 30122), sharing the skin's existing
portrait/focus renderer and Kodi's native view-state storage. Back from a show restores its selected poster. The parent-directory poster is disabled; the
controller's Back action provides navigation instead.
For these library paths the grid is the only eligible native view, selected
during Kodi's directory hand-off; there is no delayed service-side view switch.
Bumper page changes use a 160 ms directional slide of 48 design pixels,
starting only once the destination is ready. Other pages and dialogs have no
timed transitions. The three main pages
share the Home window, with their native directory providers loaded in the
background. A page request waits for its provider to finish, keeping the current
page visible until the destination is ready. Empty-state labels require a
completed listing. Tab navigation opens no modal busy dialog. Visible artwork uses
Kodi's normal texture loading, which loads images before drawing the frame;
image crossfades are disabled. Library listings use Kodi's native completed
directory hand-off and fixed geometry. Missing banner art uses a neutral
background.
Games have native game info tags
and explicitly non-playable launch actions, so video queue/play-next and
watch-state actions are not offered. GOG install/uninstall actions remain, and
More info opens a native text-viewer dialog with local installation/source details
from Games and Continue, without launching a game.
Videos combines local films and show folders alphabetically; opening
a show uses Kodi's native flattened episode navigation. The homepage uses one
stable left-aligned title control for every item type, without title scrolling
or swapping episode/game controls.
Continue has one heading with the selected item's title and a horizontal fixed
list. Its selected poster stays inset at x=70 in 1080p design coordinates. One
extra list slot extends beyond the left screen edge, allowing previous posters
to scroll fully off screen instead of clipping at the focus position. Directional
input stays within the content; the tab bar is display-only, with L/R shoulder
button cues; their duplicate footer hint is omitted. A shared skin include displays Kenney controller prompts at the bottom for
the current selection and dialog, without accepting input. It hides during
fullscreen playback and returns with the playback controls. Continue reserves
104 pixels for this bar and its bottom safe margin. Empty pages retain an invisible focus anchor. The
left/right bumpers cycle Home → Videos → Games in either direction, using
resident page selection so switching tabs does not load a new native window
or stack Back history. The screen has
no vertical scrolling or additional rail wrappers.
Continue's video cards are derived from Kodi's JSON-RPC library history and
resume points, never a second watch-history database. Each active show has one
card: resume its last episode, or advance to the next unwatched local episode
across seasons. Completed films and finished shows are omitted. Game activity
is recorded only after a real game window is successfully focused, in
`special://profile/addon_data/plugin.program.localhome/activity.sqlite`.
All cards are ordered together by last activity; unavailable/uninstalled games
are excluded. Kodi playback callbacks and successful game launches refresh the
row. No vendor client history, telemetry or extra service is involved. Game
history starts when this version is activated; game saves remain game-owned.

Kodi rewrites `guisettings.xml`. Before each launch, preparation merges only
owned GUI settings. The skin stays immutable in the Nix store; there is no
writable skin copy, snapshot restoration or runtime menu generation.

User-installed copies of managed add-ons are moved to `~/.kodi/nix-backups/`
so they cannot shadow system packages. The retired Arctic skin, Skin Shortcuts
configuration, TMDb helper settings and menu signature are also moved there
on the next launch. Changed writable settings are backed up before replacement.
Home Manager uses the existing `.backup` convention for files it takes ownership of.

Databases, watched status, resume points, thumbnails, display calibration and
other unowned GUI preferences remain writable and are not reset. The local
startup service changes only the declared source configuration rows in the
video database, using a schema check and SQLite transaction; it never replaces
the database. The media files, episode NFOs and artwork are library data, not
Nix store contents. Keep/back up `~/Videos` separately.

`game-launches.nix` declares installed executables and custom command entries.
Custom entries use a `custom:` ID, an explicit argument list, and a working
directory relative to the user's home. Hollie runs `devenv tasks run hollie:run`
from `~/projects/hollie`, building the live checkout on every launch. It uses
the same owned launch service and window hand-off as the other games.
Native Linux games use the Nix library environment `steam-run` (not the client);
Windows games use UMU and the Nix-pinned GE-Proton runner. There is no
Steam fallback, and undeclared games cannot launch. Declarations for untested
games are candidates, not claims that their builds are DRM-free. The launcher
manages the SDK's plain-text `steam_appid.txt` using the real game ID, refusing
conflicting existing files or symlinks; it never patches game binaries.
Each Windows candidate gets `~/Games/Prefixes/steam-independent-APPID` unless
an explicit prefix is declared. Original Steam prefixes/saves remain untouched;
these new prefixes do not automatically inherit arbitrary games' save data.

Every launch runs in a uniquely named transient systemd user service with
`KillMode=control-group` and a three-second termination grace period. Cancelling
startup, timing out, launcher failure, or leaving the
game all stop that service and its descendants, including detached children.
Temporary compositor query failures retry; a running game is owned by its
service rather than by the visibility of its surface. Startup retries remain bounded by the launch timeout.
A guardian watches Kodi through a pidfd and ends the service if Kodi dies.
Launcher daemons are tracked through cgroup membership, not just their first
PID. A child attempting to start a Steam consumer client makes the service fail.
Private per-launch logs live in `~/.local/state/kodi-games/`.
Steam/Gamescope remains an optional login session for maintenance; Kodi's game
catalog never invokes it. Kodi remains running while Gamescope manages game focus.

Hollow Knight's installed Windows executable is
launched through the Nix-pinned UMU launcher and GE-Proton compatibility package
runner, with GAMEID=0, its real SteamAppId, and no Steam consumer client. Its binaries and
artwork remain in the Steam-managed installation, but playing does not start
Steam, invoke its overlay/Input, or perform Steam cloud sync/achievements.
There is no automatic fallback to Steam if the independent runner is missing.
The game uses `~/Games/Prefixes/hollow-knight-standalone`; first launch copies
only save/config data from the original Steam prefix, never overwriting existing
destination saves or changing the original prefix. Back up the new prefix's
`drive_c/users/steamuser/AppData/LocalLow/Team Cherry/Hollow Knight` separately.
The original winhttp mod-loader override is retained. GE-Proton comes from
`pkgs.proton-ge-bin.steamcompattool`; its version/hash is fixed by `flake.lock`.

GOG installation state lives in `~/.local/share/gog/installed.json`; Kodi launches
installed entries' metadata-selected executables through
the same owned services, without Heroic or GOG authentication during play.
Existing prefixes stay in their original paths to preserve saves and installed
dependencies. Heroic's original data remains available for migration and
rollback; its GUI and game-launch integration have been retired.
GOG management commands and credential handling are documented in `pkgs/gog`.
The Games row also reads cached owned titles from `library.json`: uninstalled
games have dimmed labels and selecting them offers installation confirmation.
Press the controller's context-menu button (Nintendo X) on an installed GOG
game to uninstall. These actions wrap the Nix-pinned CLI in an owned service;
install cancellation stops its whole process group. Library refresh is explicit,
and the Games widget reloads after management operations. Uninstall currently
moves files into GOG recovery storage, preserving unknown saves, and therefore
does not reclaim disk space (see the GOG README).

The theatre session starts Gamescope directly on DRM/KMS, with native Wayland
Kodi as its home application. The theatre selects the RX 9070 XT (`1002:7550`):
automatic selection chooses the integrated GPU, which has no connected output.
The Kodi Wayland backend also carries a small initial-mode fix so a compositor's
windowed configure after a fullscreen request initializes the render size.
Gamescope exposes
Wayland for native clients and Xwayland for games that require X11. The skin,
media library, audio and InputPlumber profiles are shared with the prior setup.
Kodi's screensaver, pause dimming and idle shutdown are disabled, and logind's
idle action is `ignore`. TV-internal sleep timers are separate.

`localhome/game_session.py` waits up to 150 seconds for Gamescope to focus a real
game surface. Application focus uses `GAMESCOPECTRL_BASELAYER_APPID`, with Kodi
as the fallback while a game compiles or loads. The session guardians identify
their descendants using Gamescope's reaper metadata; this does not start Steam
or change the games' SDK IDs. Xwayland surfaces are assigned the game's session
role separately. Once ready, the game remains owned until its service exits,
including while the user returns to Kodi. Cancelling startup or ending Kodi
stops the owned game service and every descendant.

The input router chooses the game or Kodi profile from Gamescope's focused
application. A small Wayland client registers Home/F13 with Gamescope's action
binding protocol, so it works even while a game has focus. Home returns to
Kodi's homepage or restores the running game; game exit restores Kodi.
Duplicate launches are blocked. The X11 hand-off remains available for local
skin previews, which do not use the theatre's Gamescope session.

The optional Steam session's package disables its overlay, Switch HIDAPI and
physical Pro Controller input in SDL. A scoped udev rule denies user access to
the controller's raw HID device, preventing Steam from bypassing InputPlumber's
evdev capture. Reconnect the controller after first activation so any old
raw-HID access ACL is discarded. InputPlumber's service includes `setfacl` for
hiding the physical evdev device.
The game profile normalizes Nintendo's digital ZL/ZR into Xbox trigger axes and
matches Nintendo's printed face-button letters to Xbox/SDL prompts, not positions.
Thus physical Nintendo A/B/X/Y correspond to Xbox A/B/X/Y respectively; Kodi
keeps Nintendo A to select and B to go back. Games sort installed-first, with
alphabetical ordering inside the installed and uninstalled groups.

GOG uses `art_square` for portrait box art and `art_cover` for wide banners.
Artwork is read from GOG's cache, with Heroic's original cache retained as a
migration fallback. Extensionless cached images are linked with image extensions
under `~/.cache/kodi-localhome/artwork/` so Kodi's skin helpers recognise them.
This regenerable cache leaves the original images intact.

InputPlumber is scoped to this controller. Its D-Bus profile changes are
authorized only for the active local `louis` session. Independently launched
games use its OS-owned virtual gamepad output.

## Apply and test

```sh
sudo nixos-rebuild switch --flake /home/louis/projects/nixos#theatre
sudo systemctl restart display-manager.service
```

Restarting the display manager ends the current session; no reboot is required.
GUI edits to owned settings are reset on the next Kodi launch/rebuild. Make
lasting changes here instead. Runtime state is deliberately not declarative.

The helper tests run with:

```sh
nix shell --inputs-from . nixpkgs#python3 --command python3 tests/kodi/test_config.py
nix build .#checks.x86_64-linux.inputplumber --no-link
```
