"""Gamescope's application focus API, shared by native Wayland and Xwayland."""
import re
import subprocess

# Session roles, independent of store IDs and Steam's SDK environment.
KODI_APP = 1000000001
GAME_APP = 1000000002


def property_values(xprop, name):
    result = subprocess.run([xprop, '-root', name], capture_output=True,
                            text=True, check=True, timeout=3)
    # Ignore numbers in the property's type or a missing-property message.
    value = result.stdout.partition('=')[2]
    return [int(number, 0) for number in re.findall(r'0x[0-9a-fA-F]+|\d+', value)]


def focused(xprop):
    return next(iter(property_values(xprop, 'GAMESCOPE_FOCUSED_APP')), None)


def focus(xprop, app):
    if app not in (KODI_APP, GAME_APP):
        raise ValueError('Unknown theatre application role')
    # Keep Kodi displayed while a game compiles/loads or replaces its window.
    value = f'{GAME_APP}, {KODI_APP}' if app == GAME_APP else str(KODI_APP)
    subprocess.run([xprop, '-root', '-f', 'GAMESCOPECTRL_BASELAYER_APPID', '32c',
                    '-set', 'GAMESCOPECTRL_BASELAYER_APPID', value],
                   capture_output=True, check=True, timeout=3)
