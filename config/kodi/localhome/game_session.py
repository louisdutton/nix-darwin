"""A skin-native pending screen and owned game/Kodi focus hand-off."""
import json
import os
from pathlib import Path
import re
import sqlite3
import subprocess
import sys
import time

import xbmc
import xbmcgui

TOOLS = json.loads((Path(__file__).parent / 'launch-tools.json').read_text()) if (Path(__file__).parent / 'launch-tools.json').is_file() else {}


def command(tool, *arguments):
    result = subprocess.run([TOOLS[tool], *arguments], capture_output=True,
                            text=True, timeout=3, check=True)
    return result.stdout


def windows():
    if os.environ.get('THEATRE_COMPOSITOR') == 'gamescope':
        from gamescope import property_values
        # Gamescope exports Xwayland windows as [window, app, pid] triplets.
        listing = ' '.join(hex(window) for window in property_values(TOOLS['xprop'], 'GAMESCOPE_FOCUSABLE_WINDOWS')[::3])
    else:
        listing = command('xprop', '-root', '_NET_CLIENT_LIST')
    result = {}
    for window in re.findall(r'0x[0-9a-fA-F]+', listing):
        try:
            properties = command('xprop', '-id', window, 'WM_CLASS', '_NET_WM_PID', '_NET_WM_WINDOW_TYPE', '_NET_WM_STATE')
            classes = re.search(r'WM_CLASS\(STRING\) = (.*)', properties)
            pid = re.search(r'_NET_WM_PID\(CARDINAL\) = (\d+)', properties)
            result[window] = {'class': classes[1].lower() if classes else '',
                              'pid': pid[1] if pid else '',
                              'normal': '_NET_WM_WINDOW_TYPE_NORMAL' in properties,
                              'hidden': '_NET_WM_STATE_HIDDEN' in properties}
        except subprocess.TimeoutExpired:
            raise  # An unresponsive X server is not an empty window list.
        except (OSError, subprocess.SubprocessError):
            continue  # A window can disappear between queries.
    return result


def available_windows():
    try:
        return windows()
    except (OSError, subprocess.SubprocessError) as error:
        xbmc.log('Local Home: waiting for X11 window query: ' + str(error), xbmc.LOGWARNING)
        return None


def find_game(game, current):
    for window, info in current.items():
        if info['normal'] and info['pid']:
            try:
                arguments = Path('/proc', info['pid'], 'cmdline').read_bytes().decode(errors='replace')
                normalized = arguments.replace('\\', '/').casefold()
                if game.get('install_path'):
                    install = Path(game['install_path']).resolve()
                    cwd = Path('/proc', info['pid'], 'cwd').resolve()
                    if game['install_path'].replace('\\', '/').casefold() in normalized or cwd.is_relative_to(install):
                        return window
            except OSError:
                continue
    return None


def run_game(appid, game, spawn, timeout=150):
    if os.environ.get('THEATRE_COMPOSITOR') == 'gamescope':
        return run_gamescope_game(appid, game, spawn, timeout)
    home = xbmcgui.Window(10000)
    if home.getProperty('LocalHome.GamePending'):
        xbmcgui.Dialog().notification('Games', 'A game is already starting or running')
        return False
    home.setProperty('LocalHome.GamePending', appid)
    progress = xbmcgui.DialogProgress()
    monitor = xbmc.Monitor()
    kodi_window = None
    launch = None
    try:
        previous = windows()
        kodi_window = next((w for w, info in previous.items() if '"kodi"' in info['class']), None)
        progress.create('Starting ' + game['title'], 'Preparing your game…')
        launch = spawn()
        deadline = time.monotonic() + timeout
        while not monitor.abortRequested() and time.monotonic() < deadline:
            if progress.iscanceled():
                return False
            if launch.poll() is not None:
                xbmc.log('Local Home: failed launch log: ' + str(launch.log_path), xbmc.LOGERROR)
                xbmcgui.Dialog().notification('Games', 'Game exited before opening a window. See launch log.', time=8000)
                return False
            current = available_windows()
            if current is None:
                if monitor.waitForAbort(0.4):
                    return False
                continue
            window = find_game(game, current)
            if window:
                # Closing a modal can restore Kodi's focus: do it BEFORE
                # activating the game, never after the foreground hand-off.
                progress.close()
                try:
                    command('xdotool', 'windowactivate', window)
                except (OSError, subprocess.SubprocessError) as error:
                    # Loading or fullscreen changes can replace the window or
                    # briefly stall X11. Retry discovery within the launch deadline.
                    xbmc.log('Local Home: retrying game focus: ' + str(error), xbmc.LOGWARNING)
                    if monitor.waitForAbort(0.4):
                        return False
                    continue
                # Record only a real, successfully focused game window, never
                # install requests, failed launches or cancelled pending UI.
                from continue_watching import record_game, refresh
                try:
                    record_game(appid)
                    refresh()
                except (OSError, sqlite3.Error) as error:
                    xbmc.log('Local Home: could not record game activity: ' + str(error), xbmc.LOGWARNING)
                missing_since = None
                while not monitor.waitForAbort(0.5):
                    if launch.poll() is not None:
                        break
                    current = available_windows()
                    if current is None:
                        missing_since = None
                        continue
                    if find_game(game, current):
                        missing_since = None
                    else:
                        missing_since = missing_since or time.monotonic()
                        if time.monotonic() - missing_since > 3:
                            break  # Allow fullscreen mode/window recreation.
                return True
            progress.update(0, 'Waiting for the game window…')
            if monitor.waitForAbort(0.4):
                return False
        xbmcgui.Dialog().notification('Games', 'Launch timed out; stopping the game.', time=8000)
        return False
    finally:
        try:
            if launch is not None:
                launch.stop()
        finally:
            progress.close()
            try:
                if kodi_window and not monitor.abortRequested():
                    try:
                        command('xdotool', 'windowactivate', kodi_window)
                    except (OSError, subprocess.SubprocessError) as error:
                        xbmc.log('Local Home: could not restore Kodi focus: ' + str(error), xbmc.LOGWARNING)
            finally:
                home.clearProperty('LocalHome.GamePending')


def run_gamescope_game(appid, game, spawn, timeout):
    """A mapped, focused surface is readiness; process lifetime owns the game."""
    from gamescope import KODI_APP, GAME_APP, focus, focused
    from input_router import save_state
    home = xbmcgui.Window(10000)
    if home.getProperty('LocalHome.GamePending'):
        xbmcgui.Dialog().notification('Games', 'A game is already starting or running')
        return False
    home.setProperty('LocalHome.GamePending', appid)
    progress = xbmcgui.DialogProgress()
    monitor, launch = xbmc.Monitor(), None
    try:
        progress.create('Starting ' + game['title'], 'Preparing your game…')
        launch = spawn()
        save_state({'kodi': KODI_APP, 'game': GAME_APP})
        deadline = time.monotonic() + timeout
        focus(TOOLS['xprop'], GAME_APP)
        while not monitor.abortRequested() and time.monotonic() < deadline:
            if progress.iscanceled():
                return False
            if launch.poll() is not None:
                xbmc.log('Local Home: failed launch log: ' + str(launch.log_path), xbmc.LOGERROR)
                xbmcgui.Dialog().notification('Games', 'Game exited before opening a window. See launch log.', time=8000)
                return False
            try:
                # SDKs may set a store ID on Xwayland windows; assign the
                # session role without changing the game's SDK environment.
                current = available_windows()
                window = find_game(game, current) if current is not None else None
                if window:
                    command('xprop', '-id', window, '-f', '_STEAM_GAME', '32c',
                            '-set', '_STEAM_GAME', str(GAME_APP))
                ready = focused(TOOLS['xprop']) == GAME_APP
            except (OSError, subprocess.SubprocessError):
                ready = False
            if ready:
                progress.close()
                from continue_watching import record_game, refresh
                try:
                    record_game(appid)
                    refresh()
                except (OSError, sqlite3.Error) as error:
                    xbmc.log('Local Home: could not record game activity: ' + str(error), xbmc.LOGWARNING)
                while not monitor.waitForAbort(0.5):
                    if launch.poll() is not None:
                        break
                return True
            if monitor.waitForAbort(0.4):
                return False
        xbmcgui.Dialog().notification('Games', 'Launch timed out; stopping the game.', time=8000)
        return False
    finally:
        try:
            if launch is not None:
                launch.stop()
        finally:
            progress.close()
            save_state({'kodi': KODI_APP, 'game': None})
            home.clearProperty('LocalHome.GamePending')
            try:
                focus(TOOLS['xprop'], KODI_APP)
            except (OSError, subprocess.SubprocessError) as error:
                xbmc.log('Local Home: could not restore Gamescope focus: ' + str(error), xbmc.LOGWARNING)


if __name__ == '__main__':
    from default import launch_game
    launch_game(sys.argv[1], supervised=True)
