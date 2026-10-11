"""Session-owned controller routing, for Kodi and independently launched games."""
import json
import os
import re
import subprocess
import tempfile
import time

import xbmc

from game_session import command, find_game, windows
from session_home import runtime


def choose_game(catalog, current, active, previous_game=None):
    matches = []
    for game in catalog.values():
        for window, info in current.items():
            if steam_ui(info):
                continue
            if find_game(game, {window: info}):
                matches.append(window)
    return active if active in matches else previous_game if previous_game in matches else next(iter(matches), None)


def steam_ui(info):
    classes = re.findall(r'"([^"]+)"', info['class'])
    return any(value in ('steam', 'steamwebhelper') for value in classes)


def save_state(state):
    descriptor, temporary = tempfile.mkstemp(prefix='.kodi-game-', dir=runtime())
    try:
        with os.fdopen(descriptor, 'w') as target:
            json.dump(state, target)
        os.replace(temporary, runtime() / 'kodi-localhome-game.json')
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


class Router:
    def __init__(self):
        self.applied = {}
        self.state = None
        self.game = None
        self.native_enabled = None

    def native_input(self, enabled):
        if self.native_enabled == enabled:
            return
        response = json.loads(xbmc.executeJSONRPC(json.dumps({
            'jsonrpc': '2.0', 'id': 1, 'method': 'Settings.SetSettingValue',
            'params': {'setting': 'input.enablejoystick', 'value': enabled},
        })))
        if response.get('result') is not True:
            raise RuntimeError('Kodi refused controller fallback configuration')
        self.native_enabled = enabled

    def profile(self, mode):
        try:
            listing = command('busctl', '--system', '--list', 'tree', 'org.shadowblip.InputPlumber')
        except (OSError, subprocess.SubprocessError):
            self.applied.clear()
            raise
        devices = set(re.findall(r'/org/shadowblip/InputPlumber/CompositeDevice(\d+)\b', listing))
        self.applied = {key: value for key, value in self.applied.items() if key in devices}
        for device in devices:
            if self.applied.get(device) != mode:
                command('inputplumber', 'device', device, 'profile', 'load', '/etc/inputplumber/profiles.d/' + mode + '.yaml')
                self.applied[device] = mode
        return bool(devices)

    def tick(self, catalog):
        if os.environ.get('THEATRE_COMPOSITOR') == 'gamescope':
            from gamescope import focused, GAME_APP
            from game_session import TOOLS
            managed = self.profile('game' if focused(TOOLS['xprop']) == GAME_APP else 'kodi')
            self.native_input(not managed)
            return
        current = windows()
        active_property = command('xprop', '-root', '_NET_ACTIVE_WINDOW')
        active = next(iter(re.findall(r'0x[0-9a-fA-F]+', active_property)), None)
        kodi = next((window for window, info in current.items() if '"kodi"' in info['class']), None)
        game = choose_game(catalog, current, active, self.game)
        # A running game can remain open while Kodi has focus. Its controller
        # gets neutralized when switching to keyboard navigation for Kodi.
        managed = self.profile('game' if game and active == game else 'kodi')
        self.native_input(not managed)
        if self.game and not game and kodi:
            command('xdotool', 'windowactivate', kodi)
        self.game = game
        state = {'kodi': kodi, 'game': game}
        if state != self.state:
            save_state(state)
            self.state = state
        # An explicit maintenance flag is the only way to expose client UI.
        if not (runtime() / 'kodi-steam-maintenance').exists():
            for window, info in current.items():
                if window != game and steam_ui(info) and not info.get('hidden'):
                    command('xdotool', 'windowminimize', window)
                    if active == window and kodi:
                        command('xdotool', 'windowactivate', game or kodi)


def main():
    from default import game_catalog
    monitor, router = xbmc.Monitor(), Router()
    catalog, refresh, last_warning = {}, 0, 0
    try:
        while not monitor.abortRequested():
            try:
                now = time.monotonic()
                if now >= refresh:
                    catalog, refresh = game_catalog(), now + 15
                router.tick(catalog)
            except Exception as error:
                # If the daemon is gone, don't strand the user with no input.
                # Existing devices still receive their declared keyboard
                # profile; do not restore joystick consumption behind games.
                if not router.applied:
                    try:
                        router.native_input(True)
                    except Exception:
                        pass
                # Retry hotplug/service startup without flooding Kodi's log.
                if time.monotonic() - last_warning > 30:
                    xbmc.log('Local Home: input routing retry: ' + str(error), xbmc.LOGWARNING)
                    last_warning = time.monotonic()
            if monitor.waitForAbort(0.25):
                break
    finally:
        try:
            router.profile('kodi')
        except Exception:
            pass
