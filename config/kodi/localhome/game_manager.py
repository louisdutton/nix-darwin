"""Controller-friendly management; all operations go through the pinned CLI."""
import fcntl
import json
import os
from pathlib import Path
import sys
import time
import tempfile

import xbmc
import xbmcgui

from game_session import TOOLS
from owned_launch import OwnedLaunch


def read_status(path):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return {}


def size_text(value):
    value = float(value)
    for unit in ('B', 'KiB', 'MiB', 'GiB', 'TiB'):
        if value < 1024 or unit == 'TiB':
            return f'{value:.1f} {unit}'
        value /= 1024


def progress_text(status):
    phase = status.get('phase')
    if phase == 'registering':
        return 'Download finished. Registering the game…'
    if phase != 'installing':
        return 'Fetching manifests and preparing the installation…'
    downloaded = size_text(status.get('downloaded_bytes', 0))
    total = size_text(status['download_bytes']) if status.get('download_bytes') else 'unknown total'
    speed = size_text(status.get('speed_bytes', 0)) + '/s'
    eta = status.get('eta_seconds')
    eta = 'calculating…' if eta is None else f'{int(eta) // 3600:02d}:{int(eta) // 60 % 60:02d}:{int(eta) % 60:02d}'
    return f'Downloaded: {downloaded} / {total}\nSpeed: {speed} · ETA: {eta}\nInstalling: {status.get("percent", 0):.1f}% · Cancel stops the download'


def execute_operation(argv, title, status_path, action):
    progress, launch, monitor = xbmcgui.DialogProgress(), None, xbmc.Monitor()
    try:
        progress.create(title, 'Fetching installation details…' if action == 'info' else 'Preparing…')
        launch = OwnedLaunch({'command': argv}, TOOLS)
        while launch.poll() is None:
            if progress.iscanceled() and action != 'uninstall':
                xbmcgui.Dialog().notification('Games', 'Cancelled. Partial downloads are kept for retry.' if action == 'install' else 'Cancelled')
                return False
            if monitor.waitForAbort(0.3):
                return False
            status = read_status(status_path)
            percent = min(99, max(0, int(status.get('percent', 0))))
            message = (progress_text(status) if action == 'install' else
                       'Fetching download size and checking free space…' if action == 'info' else
                       'Moving to recovery storage…' if action == 'uninstall' else
                       'Refreshing owned library…')
            progress.update(percent, message)
        if launch.poll() != 0:
            xbmcgui.Dialog().notification('Games', 'Operation failed. Private log: ' + str(launch.log_path), time=10000)
            return False
        progress.update(100, 'Complete')
        return True
    finally:
        try:
            if launch:
                launch.stop()
        finally:
            progress.close()


def installation_estimate(appid, title, status_path):
    if not execute_operation([TOOLS['gog'], 'info', appid, '--status-file', str(status_path)],
                             'Install: ' + title, status_path, 'info'):
        return None
    status = read_status(status_path)
    if status.get('phase') != 'ready' or not all(k in status for k in ('download_bytes', 'installed_bytes', 'free_bytes')):
        xbmcgui.Dialog().notification('Games', 'Could not obtain installation sizes')
        return None
    return status


def manage(action, key=''):
    from default import game_catalog
    if action not in ('install', 'uninstall', 'refresh'):
        return False
    games = game_catalog()
    if action != 'refresh' and (not key.startswith('gog:') or not key[4:].isdecimal() or key not in games):
        return False
    game = games.get(key, {})
    if action == 'install' and game.get('installed', True):
        return False
    if action == 'uninstall' and not game.get('installed'):
        return False
    home = xbmcgui.Window(10000)
    if home.getProperty('LocalHome.GamePending'):
        xbmcgui.Dialog().notification('Games', 'Close the running game before managing installations.')
        return False
    runtime = Path(os.environ.get('XDG_RUNTIME_DIR', '/run/user/' + str(os.getuid())))
    with (runtime / 'kodi-gog-management.lock').open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            xbmcgui.Dialog().notification('Games', 'Another library operation is already running.')
            return False
        title = game.get('title', 'GOG library')
        directory = Path.home() / '.local/state/kodi-games'
        directory.mkdir(parents=True, exist_ok=True, mode=0o700)
        try:
            with tempfile.TemporaryDirectory(prefix='gog-ui-', dir=directory) as temporary:
                status_path = Path(temporary) / 'status.json'
                if action == 'install':
                    estimate = installation_estimate(key[4:], title, status_path)
                    if estimate is None:
                        return False
                    message = (f'Download: {size_text(estimate["download_bytes"])}\n'
                               f'Installed size: {size_text(estimate["installed_bytes"])}\n'
                               f'Available space: {size_text(estimate["free_bytes"])}\n'
                               'Full-install estimates; retries may download less. ETA appears after downloading starts.')
                    if estimate['free_bytes'] < estimate['installed_bytes']:
                        xbmcgui.Dialog().ok('Not enough disk space', message)
                        return False
                    if estimate['free_bytes'] < estimate.get('recommended_free_bytes', estimate['installed_bytes']):
                        message += '\nWarning: limited headroom for temporary files and the Wine prefix.'
                    if not xbmcgui.Dialog().yesno('Install ' + title, message):
                        return False
                elif action == 'uninstall':
                    if not xbmcgui.Dialog().yesno('Uninstall ' + title,
                            'Move this game to recovery storage? Saves and prefixes are kept. This does not free disk space.'):
                        return False
                argv = [TOOLS['gog'], 'list'] if action == 'refresh' else [TOOLS['gog'], action, key[4:]]
                if action == 'install':
                    argv += ['--status-file', str(status_path)]
                if not execute_operation(argv, action.title() + ': ' + title, status_path, action):
                    return False
                xbmcgui.Dialog().notification('Games', action.title() + ' complete')
                return True
        except (OSError, RuntimeError, KeyError) as error:
            xbmc.log('Local Home: management failed: ' + type(error).__name__, xbmc.LOGERROR)
            xbmcgui.Dialog().notification('Games', 'Could not manage this game')
            return False
        finally:
            if not xbmc.Monitor().abortRequested():
                home.setProperty('LocalHome.GamesReload', str(time.monotonic_ns()))
                xbmc.executebuiltin('Container.Refresh')


if __name__ == '__main__':
    manage(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else '')
