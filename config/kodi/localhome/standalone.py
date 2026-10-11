"""Explicit independent runners for owned, installed games; no Steam fallback."""
import os
from pathlib import Path
import shutil


def custom_launch(declaration, home=None):
    """Run a declared command from a live checkout, owned like any other game."""
    home = Path.home() if home is None else Path(home)
    directory = (home / declaration['workingDirectory']).resolve()
    command = declaration['command']
    if not directory.is_dir():
        raise RuntimeError('Custom game checkout is missing: ' + str(directory))
    if not isinstance(command, list) or not command or not all(isinstance(arg, str) for arg in command):
        raise RuntimeError('Custom game command must be a nonempty argument list')
    if not Path(command[0]).is_absolute() or not Path(command[0]).is_file():
        raise RuntimeError('Custom game launcher is missing or not an absolute path')
    environment = dict(os.environ)
    for name in ('LD_PRELOAD', 'LD_LIBRARY_PATH', 'STEAM_RUNTIME_LIBRARY_PATH'):
        environment.pop(name, None)
    environment.update({
        'SDL_JOYSTICK_HIDAPI_SWITCH': '0',
        'SDL_GAMECONTROLLER_IGNORE_DEVICES': '0x057e/0x2009',
        **declaration.get('environment', {}),
    })
    return {'command': command, 'cwd': str(directory), 'install_path': str(directory),
            'environment': environment, 'source': 'Custom game', 'installed': True}


def launch_config(appid, declaration, installation, steam, tools, home=None):
    home = Path.home() if home is None else Path(home)
    install = Path(installation).resolve()
    executable = (install / declaration['executable']).resolve()
    if not executable.is_relative_to(install) or not executable.is_file():
        raise RuntimeError('Declared game executable is missing or outside its installation')
    native = declaration.get('runner', 'umu') == 'native'
    prefix = home / declaration.get('prefix', 'Games/Prefixes/steam-independent-' + appid)
    proton = home / declaration['proton'] if 'proton' in declaration else Path(tools.get('proton', '/nonexistent/proton'))
    if not native and not (proton / 'proton').is_file():
        raise RuntimeError('Declared independent Proton runner is not installed')
    environment = dict(os.environ)
    # UMU provides the compatibility runtime without a Steam consumer client.
    # GAMEID=0 disables title-specific protonfixes/Steam launch integration.
    environment.update({
        'WINEPREFIX': str(prefix), 'PROTONPATH': str(proton),
        'GAMEID': '0', 'STORE': 'none', 'SteamAppId': appid, 'SteamGameId': appid,
        'SteamNoOverlayUI': '1', 'SDL_JOYSTICK_HIDAPI_SWITCH': '0',
        'SDL_GAMECONTROLLER_IGNORE_DEVICES': '0x057e/0x2009',
        **declaration.get('environment', {}),
    })
    game = {
        'command': [tools['steam-run' if native else 'umu'], str(executable)], 'environment': environment,
        'cwd': str(executable.parent),
        'source': 'Standalone (native)' if native else 'Standalone (UMU)', 'install_path': str(install),
        'steam_appid': appid, 'appid_path': str(executable.parent / 'steam_appid.txt'),
    }
    if 'saveDirectory' in declaration:
        game.update({
            'save_source': str(Path(steam) / 'steamapps/compatdata' / appid / 'pfx' / declaration['saveDirectory']),
            'save_target': str(prefix / declaration['saveDirectory']),
        })
    return game


def gog_launch(record, tools):
    install = Path(record['install_path']).resolve()
    executable = Path(record['executable']).resolve()
    cwd = Path(record.get('working_dir', str(install))).resolve()
    if not executable.is_file() or not executable.is_relative_to(install) or not cwd.is_relative_to(install):
        raise RuntimeError('GOG executable/working directory is missing or outside installation')
    native = record.get('platform') == 'linux'
    environment = dict(os.environ)
    environment.update({
        'WINEPREFIX': record['prefix'], 'PROTONPATH': tools['proton'],
        'GAMEID': '0', 'STORE': 'gog', 'SteamAppId': '0', 'SteamGameId': '0',
        'SteamNoOverlayUI': '1', 'SDL_JOYSTICK_HIDAPI_SWITCH': '0',
        'SDL_GAMECONTROLLER_IGNORE_DEVICES': '0x057e/0x2009',
        **record.get('environment', {}),
    })
    return {'command': [tools['steam-run' if native else 'umu'], str(executable), *record.get('arguments', [])],
            'environment': environment, 'cwd': str(cwd), 'install_path': str(install),
            'source': 'GOG (native)' if native else 'GOG (UMU)'}


def prepare_game(game):
    """Standard SDK launch metadata only; never patch executable code."""
    if game.get('steam_appid'):
        path = Path(game['appid_path'])
        if path.is_symlink():
            raise RuntimeError('Refusing a symlinked steam_appid.txt')
        expected = game['steam_appid']
        try:
            with path.open('x') as output:
                output.write(expected + '\n')
        except FileExistsError:
            if path.read_text().strip() != expected:
                raise RuntimeError('Existing steam_appid.txt does not match this game')
    if 'save_source' in game:
        import_saves(game)


def import_saves(game):
    """Copy save data only; never replace either prefix or overwrite progress."""
    source, target = Path(game['save_source']), Path(game['save_target'])
    if not source.is_dir():
        return
    target.mkdir(parents=True, exist_ok=True)
    for item in source.iterdir():
        if item.is_symlink() or not item.is_file():
            continue
        if not (item.name.startswith(('user', 'shared')) and '.dat' in item.name or item.name == 'AppConfig.ini'):
            continue
        destination = target / item.name
        try:
            # Exclusive creation also guards two overlapping launch requests.
            with destination.open('xb') as output, item.open('rb') as original:
                shutil.copyfileobj(original, output)
        except FileExistsError:
            continue
