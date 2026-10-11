"""Trusted session shortcut: toggle Kodi/game, never invoke Steam's UI."""
import fcntl
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import sys
import time


def runtime():
    return Path(os.environ.get('XDG_RUNTIME_DIR', '/run/user/' + str(os.getuid())))


def toggle(xprop, xdotool):
    # Keep repeated key presses from creating simultaneous focus changes.
    with (runtime() / 'kodi-localhome-home.lock').open('a+') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        lock.seek(0)
        last = lock.read()
        if last and time.monotonic() - float(last) < 0.7:
            return
        lock.seek(0)
        lock.truncate()
        lock.write(str(time.monotonic()))
        lock.flush()
        try:
            state = json.loads((runtime() / 'kodi-localhome-game.json').read_text())
            if os.environ.get('THEATRE_COMPOSITOR') == 'gamescope':
                from gamescope import focus, focused, KODI_APP, GAME_APP
                target = GAME_APP if focused(xprop) == KODI_APP and state.get('game') == GAME_APP else KODI_APP
                focus(xprop, target)
                if target == KODI_APP:
                    kodi_home()
                return
            listing = subprocess.check_output([xprop, '-root', '_NET_CLIENT_LIST', '_NET_ACTIVE_WINDOW'], text=True, timeout=3)
            active = re.search(r'_NET_ACTIVE_WINDOW.*?(0x[0-9a-fA-F]+)', listing)
            clients = set(re.findall(r'0x[0-9a-fA-F]+', listing.split('_NET_ACTIVE_WINDOW')[0]))
            kodi, game = state.get('kodi'), state.get('game')
            target = game if active and active[1] == kodi and game in clients else kodi
            if target not in clients or not re.fullmatch(r'0x[0-9a-fA-F]+', target):
                return
            subprocess.run([xdotool, 'windowactivate', target], check=True, timeout=3)
            if target == kodi:
                kodi_home()
        except (OSError, ValueError, subprocess.SubprocessError):
            return


def kodi_home():
    request = {'jsonrpc': '2.0', 'id': 1, 'method': 'Input.Home'}
    with socket.create_connection(('127.0.0.1', 9090), timeout=1) as connection:
        connection.sendall(json.dumps(request).encode())
        connection.recv(4096)


if __name__ == '__main__':
    toggle(*sys.argv[1:3])
