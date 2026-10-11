"""Opt-in Kodi smoke test: private profile/display, real audio IPC, bounded resources.

Run: python3 tests/kodi/test_playback.py /nix/store/...-kodi/bin/kodi episode.mkv [...]
This tests decoding/audio startup, not physical HDMI output or TV hotplug.
"""
import argparse
import codecs
import json
import os
from pathlib import Path
import select
import signal
import shutil
import socket
import sqlite3
import subprocess
import sys
import tempfile
import time
import uuid
import xml.etree.ElementTree as ET


def stop(process):
    if process.poll() is None:
        os.killpg(process.pid, signal.SIGTERM)
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait(timeout=5)


def main(binary, media, source_userdata=None, expected_skin=None):
    with tempfile.TemporaryDirectory(prefix='kodi-playback-') as temporary:
        base = Path(temporary)
        userdata = base / 'profile/userdata'
        history = None
        if source_userdata:
            shutil.copytree(source_userdata, userdata, symlinks=False)
            # Dereferenced Home Manager files retain their immutable store modes.
            # Only the disposable copy is made writable for this test.
            for directory, _, files in os.walk(userdata):
                os.chmod(directory, 0o700)
                for name in files:
                    os.chmod(Path(directory) / name, 0o600)
            databases = list((userdata / 'Database').glob('MyVideos*.db'))
            database = max(databases, key=lambda p: int(p.stem.removeprefix('MyVideos')))
            connection = sqlite3.connect(database)
            try:
                if os.environ.get('KODI_TEST_EMPTY_HOME'):
                    connection.execute('UPDATE files SET playCount=0,lastPlayed=NULL')
                    connection.execute('DELETE FROM bookmark')
                    connection.commit()
                    activity = userdata / 'addon_data/plugin.program.localhome/activity.sqlite'
                    if activity.exists():
                        with sqlite3.connect(activity) as games_history:
                            games_history.execute('DELETE FROM games')
                history = dict(connection.execute(
                    'SELECT idEpisode,coalesce(files.playCount,0) FROM episode '
                    'JOIN files ON episode.idFile=files.idFile'))
            finally:
                connection.close()
        else:
            userdata.mkdir(parents=True)
        if expected_skin:
            # Simulate the Home Manager-owned files in the disposable profile,
            # instead of accidentally testing menu declarations from a backup.
            assets = Path(__file__).resolve().parents[2] / 'config/kodi'

            (userdata / 'keymaps').mkdir(exist_ok=True)
            shutil.copyfile(assets / 'gamepad.xml', userdata / 'keymaps/local-home-gamepad.xml')
            # Exercise overflowing descriptions without changing the real library.
            scroll_fixture = base / 'description-fixture.py'
            scroll_fixture.write_text("import xbmcgui\nxbmcgui.Window(10000).setProperty('LocalHome.GameInfo.Description', "
                                      + repr('Explore a mysterious world filled with secrets and adventures. ' * 100) + ")\n")
            keymap = ET.Element('keymap')
            keyboard = ET.SubElement(ET.SubElement(keymap, 'window1100'), 'keyboard')
            ET.SubElement(keyboard, 'f10').text = 'RunScript(' + str(scroll_fixture) + ')'
            for key, title in [('f11', 'The Witcher 3: Wild Hunt — Complete Edition'),
                               ('f12', 'The Extremely Long Complete Collection of Extraordinary Adventures Across Mysterious Worlds and Forgotten Kingdoms')]:
                title_fixture = base / (key + '-title-fixture.py')
                title_fixture.write_text("import sys, xbmcaddon, xbmcgui\nsys.path.insert(0, xbmcaddon.Addon('plugin.program.localhome').getAddonInfo('path'))\n"
                                         "import default\nxbmcgui.Window(10000).setProperty('LocalHome.GameInfo.Title', default.inspector_title(" + repr(title) + "))\n")
                ET.SubElement(keyboard, key).text = 'RunScript(' + str(title_fixture) + ')'
            ET.ElementTree(keymap).write(userdata / 'keymaps/zz-description-fixture.xml')
        with socket.socket() as reservation:
            reservation.bind(('127.0.0.1', 0))
            port = reservation.getsockname()[1]
        settings = ET.Element('settings', version='2')
        ET.SubElement(settings, 'resolutions')
        ET.SubElement(settings, 'viewstates')
        for key, value in {
            'audiooutput.audiodevice': 'PIPEWIRE:Default|Default Output Device (PIPEWIRE)',
            'audiooutput.passthrough': 'false',
            'services.esenabled': 'true',
            'services.esallinterfaces': 'false',
            'services.webserver': 'false',
            'services.zeroconf': 'false',
            'input.enablejoystick': 'false',
            'lookandfeel.skin': 'skin.estuary',
            'screensaver.mode': '',
        }.items():
            ET.SubElement(settings, 'setting', id=key).text = value
        ET.ElementTree(settings).write(userdata / 'guisettings.xml')
        (userdata / 'advancedsettings.xml').write_text(
            f'<advancedsettings><jsonrpc><tcpport>{port}</tcpport></jsonrpc>'
            '<loglevel hide="true">1</loglevel>'
            '<video><vaapi>false</vaapi></video></advancedsettings>')
        readfd, writefd = os.pipe()
        with (base / 'xvfb.log').open('wb') as output:
            display = subprocess.Popen(
                ['Xvfb', '-displayfd', str(writefd), '-screen', '0', '1280x720x24', '-nolisten', 'tcp'],
                pass_fds=[writefd], stdout=output, stderr=output, start_new_session=True)
        os.close(writefd)
        kodi = None
        scope = 'kodi-playback-' + uuid.uuid4().hex + '.scope'
        try:
            if not select.select([readfd], [], [], 10)[0]:
                raise RuntimeError('Xvfb did not become ready')
            number = os.read(readfd, 32).decode().strip()
            env = dict(os.environ, DISPLAY=':' + number, KODI_DATA=str(base / 'profile'),
                       LIBGL_ALWAYS_SOFTWARE='1')
            env.pop('KODI_AE_SINK', None)
            def screenshot(name):
                destination = os.environ.get('KODI_TEST_ARTIFACTS')
                capture = os.environ.get('KODI_TEST_CAPTURE')
                if destination and capture:
                    Path(destination).mkdir(parents=True, exist_ok=True)
                    time.sleep(0.4)
                    subprocess.run([capture, '-display', ':' + number, '-window', 'root',
                                    str(Path(destination) / (name + '.png'))],
                                   check=True, timeout=10)
            with (base / 'stdout.log').open('wb') as output:
                kodi = subprocess.Popen(
                    ['systemd-run', '--user', '--scope', '--quiet', '--collect', '--unit=' + scope,
                     '--property=TimeoutStopSec=3s', '--property=CPUQuota=200%',
                     '--property=MemoryMax=2G', binary, '--audio-backend=pipewire', '-fs'],
                    env=env, stdout=output, stderr=output, start_new_session=True)
            deadline = time.monotonic() + 40
            while True:
                if kodi.poll() is not None:
                    raise RuntimeError('Kodi exited before RPC became ready')
                try:
                    connection = socket.create_connection(('127.0.0.1', port), timeout=1)
                    break
                except OSError:
                    if time.monotonic() >= deadline:
                        raise RuntimeError('Kodi RPC did not become ready')
                    time.sleep(0.25)
            with connection:
                connection.settimeout(30)
                decoder = json.JSONDecoder()
                utf8 = codecs.getincrementaldecoder('utf-8')()
                buffer = ''
                request_id = 0

                def rpc(method, params=None):
                    nonlocal buffer, request_id
                    request_id += 1
                    message = {'jsonrpc': '2.0', 'id': request_id, 'method': method}
                    if params is not None:
                        message['params'] = params
                    connection.sendall(json.dumps(message).encode() + b'\n')
                    while True:
                        buffer = buffer.lstrip()
                        try:
                            result, end = decoder.raw_decode(buffer)
                        except json.JSONDecodeError:
                            chunk = connection.recv(65536)
                            if not chunk:
                                raise RuntimeError('Kodi closed RPC connection')
                            buffer += utf8.decode(chunk)
                            continue
                        buffer = buffer[end:]
                        if result.get('id') == request_id:
                            if 'error' in result:
                                raise RuntimeError(result['error'])
                            return result.get('result')

                rpc('Application.SetMute', {'mute': True})
                if expected_skin:
                    skin = rpc('Settings.GetSettingValue', {'setting': 'lookandfeel.skin'})['value']
                    if skin != expected_skin:
                        raise RuntimeError(f'Skin fell back unexpectedly: {skin}')
                    print(f'PASS managed skin loaded: {skin}', flush=True)
                    addon = rpc('Addons.GetAddonDetails', {
                        'addonid': 'plugin.program.localhome', 'properties': ['enabled']})['addon']
                    if not addon['enabled']:
                        raise RuntimeError('Local Home add-on was not enabled')
                    skin_path = Path(rpc('Addons.GetAddonDetails', {
                        'addonid': expected_skin, 'properties': ['path']})['addon']['path'])
                    tree = ET.parse(skin_path / '1080i/Includes_Theatre.xml')
                    ids = ['3011199', '3011399']
                    if tree.find("include[@name='TheatreContinue']") is None:
                        raise RuntimeError('Missing bottom Continue rail')
                    if (base / 'profile/addons/skin.theatre').exists():
                        raise RuntimeError('Immutable skin was copied into the profile')
                    print('PASS immutable static Home layout loaded', flush=True)
                    native_shows = rpc('VideoLibrary.GetTVShows', {'properties': ['title', 'art', 'plot', 'year']})
                    print(f"PASS native TV library: {len(native_shows.get('tvshows', []))} shows", flush=True)
                    library = rpc('Files.GetDirectory', {
                        'directory': 'plugin://plugin.program.localhome/?section=library',
                        'media': 'files', 'properties': ['title', 'art']})
                    if not any(item['file'].startswith('videodb://tvshows/titles/')
                               for item in library.get('files', [])):
                        raise RuntimeError('Combined Library lost the local shows')
                    print(f"PASS combined native Library: {len(library.get('files', []))} items", flush=True)
                    listing = rpc('Files.GetDirectory', {
                        'directory': 'plugin://plugin.program.localhome/?section=continue',
                        'media': 'files', 'properties': ['title', 'art']})
                    if any(not item['file'].startswith(('/', 'plugin://plugin.program.localhome/'))
                           for item in listing.get('files', [])):
                        raise RuntimeError('Continue row exposed a non-local launch target')
                    print(f"PASS native Continue directory: {len(listing.get('files', []))} items", flush=True)
                    helper_path = Path(binary).resolve().parents[1] / 'share/kodi/addons/plugin.video.themoviedb.helper/addon.xml'
                    if helper_path.exists():
                        raise RuntimeError('Static skin still bundles the online metadata helper')
                    # The service schedules its first scan three seconds after
                    # startup. The static skin is ready before that scan, so wait
                    # before sending one-shot clicks into a refreshing library.
                    time.sleep(5)
                    deadline = time.monotonic() + 40
                    scanning = 'Library.IsScanningVideo'
                    while rpc('XBMC.GetInfoBooleans', {'booleans': [scanning]}).get(scanning):
                        if time.monotonic() >= deadline:
                            raise RuntimeError('Initial library scan did not finish')
                        time.sleep(0.2)
                    rpc('GUI.ActivateWindow', {'window': 'home'})
                    def expect_focus(control):
                        label = ('ControlGroup(30113).HasFocus()' if control == 30113
                                 else 'Control.HasFocus(' + str(control) + ')')
                        deadline = time.monotonic() + 8
                        while not rpc('XBMC.GetInfoBooleans', {'booleans': [label]}).get(label):
                            if time.monotonic() >= deadline:
                                state = rpc('XBMC.GetInfoLabels', {'labels': [
                                    'Container(30111).NumItems',
                                    'Container(30113).NumItems', 'System.CurrentControl', 'Container.FolderPath', 'Container.Viewmode', 'Container.Content', 'System.CurrentWindow']})
                                visible = rpc('XBMC.GetInfoBooleans', {'booleans': [
                                    'Control.IsVisible(30111)',
                                    'Control.IsVisible(30113)', 'Control.IsVisible(610)', 'String.StartsWith(Container.FolderPath,plugin://plugin.program.localhome/)', 'Container.IsUpdating']})
                                screenshot('failure')
                                raise RuntimeError('Navigation did not focus row ' + str(control) + ': ' + str(state) + str(visible))
                            time.sleep(0.1)
                    def expect_prompts(visible, selection=None):
                        checks = ['Control.IsVisible(30900)']
                        if selection is not None:
                            checks += ['Control.IsVisible(30902)', 'Control.IsVisible(30904)']
                        state = rpc('XBMC.GetInfoBooleans', {'booleans': checks})
                        if state.get(checks[0], False) != visible:
                            raise RuntimeError('Button prompts have wrong visibility: ' + str(state))
                        if selection is not None and any(state.get(key, False) != selection for key in checks[1:]):
                            raise RuntimeError('Button prompts offer unavailable selection actions: ' + str(state))
                    empty_home = bool(os.environ.get('KODI_TEST_EMPTY_HOME'))
                    expect_focus(30110 if empty_home else 30111)
                    expect_prompts(True, not empty_home)
                    screenshot('home')
                    if not empty_home:
                        for action, target in [('Input.Up', 30111), ('Input.Down', 30111)]:
                            rpc(action)
                            expect_focus(target)
                    print('PASS directional input stays in Continue', flush=True)
                    if not empty_home:
                        rpc('Input.Right')
                        time.sleep(0.3)
                        screenshot('home-scroll')
                        rpc('Input.Left')
                        rpc('Input.Up')
                    expect_focus(30110 if empty_home else 30111)
                    subprocess.run(['xdotool', 'key', '--clearmodifiers', 'Next'], env=env, check=True)
                    expect_focus(30121)
                    checks = ['Control.IsVisible(' + str(view) + ')' for view in (50, 55, 500, 550)]
                    if any(rpc('XBMC.GetInfoBooleans', {'booleans': checks}).values()):
                        raise RuntimeError('A competing native view can flash through the library grid')
                    expect_prompts(True, True)
                    screenshot('watch')
                    rpc('Input.Right')
                    selected_show = rpc('XBMC.GetInfoLabels', {'labels': ['Container(30121).ListItem.Label']})['Container(30121).ListItem.Label']
                    rpc('Input.Select')
                    deadline = time.monotonic() + 8
                    while rpc('XBMC.GetInfoLabels', {'labels': ['Container.Content']}).get('Container.Content') != 'episodes':
                        if time.monotonic() >= deadline:
                            raise RuntimeError('Show did not open its continuous episode list')
                        time.sleep(0.1)
                    screenshot('episodes')
                    subprocess.run(['xdotool', 'key', '--clearmodifiers', 'c'], env=env, check=True)
                    deadline = time.monotonic() + 8
                    while not rpc('XBMC.GetInfoBooleans', {'booleans': ['Window.IsActive(contextmenu)']}).get('Window.IsActive(contextmenu)'):
                        if time.monotonic() >= deadline:
                            raise RuntimeError('Episode Options did not open')
                        time.sleep(0.1)
                    screenshot('episodes-options')
                    rpc('Input.Back')
                    rpc('Input.Back')
                    expect_focus(30121)
                    if rpc('XBMC.GetInfoLabels', {'labels': ['Container(30121).ListItem.Label']})['Container(30121).ListItem.Label'] != selected_show:
                        raise RuntimeError('Returning from episodes lost the selected show')
                    rpc('Input.Up')
                    expect_focus(30121)
                    # Select Games explicitly; tab focus does not depend on the previous native window.
                    subprocess.run(['xdotool', 'key', '--clearmodifiers', 'Next'], env=env, check=True)
                    expect_focus(30122)
                    grid = rpc('XBMC.GetInfoLabels', {'labels': ['Container.Content', 'Container.Viewmode']})
                    if rpc('XBMC.GetInfoLabels', {'labels': ['Window(Home).Property(LocalHome.Page)']})['Window(Home).Property(LocalHome.Page)'] != 'games':
                        raise RuntimeError('Games page did not become active')
                    expect_prompts(True, True)
                    screenshot('play')
                    if int(rpc('XBMC.GetInfoLabels', {'labels': ['Container(30122).NumItems']})['Container(30122).NumItems']) > 8:
                        rpc('Input.Down')
                        screenshot('game-grid-second-row')
                        rpc('Input.Up')
                    print('PASS Watch and Play open portrait grids, Back restores the home tile', flush=True)
                    subprocess.run(['xdotool', 'key', '--clearmodifiers', 'c'], env=env, check=True)
                    time.sleep(0.3)
                    labels = []
                    for _ in range(20):
                        label = rpc('XBMC.GetInfoLabels', {'labels': ['System.CurrentControl']}).get('System.CurrentControl', '')
                        if label in labels:
                            break
                        labels.append(label)
                        rpc('Input.Down')
                        time.sleep(0.05)
                    if not labels or any(any(word in label.casefold() for word in (
                            'queue', 'play next', 'watched', 'resume', 'play from here')) for label in labels):
                        raise RuntimeError('Invalid native game context actions: ' + str(labels))
                    if any('favourite' in label.casefold() for label in labels):
                        raise RuntimeError('Removed favourites action is still offered: ' + str(labels))
                    if 'More info' not in labels:
                        raise RuntimeError('Game context menu lost More info: ' + str(labels))
                    # Cycle back to More info and exercise the actual action.
                    for _ in range(20):
                        label = rpc('XBMC.GetInfoLabels', {'labels': ['System.CurrentControl']}).get('System.CurrentControl', '')
                        if label == 'More info':
                            break
                        rpc('Input.Down')
                        time.sleep(0.05)
                    rpc('Input.Select')
                    deadline = time.monotonic() + 8
                    info_window = 'Window.IsActive(11100)'
                    while not rpc('XBMC.GetInfoBooleans', {'booleans': [info_window]}).get(info_window):
                        if time.monotonic() >= deadline:
                            raise RuntimeError('More info did not open the game details dialog')
                        time.sleep(0.1)
                    if not rpc('XBMC.GetInfoBooleans', {'booleans': ['Control.IsVisible(30902)']}).get('Control.IsVisible(30902)'):
                        raise RuntimeError('Game inspector lost its Select prompt')
                    screenshot('game-details')
                    rpc('Input.Back')
                    expect_focus(30122)
                    selected_game = rpc('XBMC.GetInfoLabels', {'labels': ['Container(30122).ListItem.Label']})['Container(30122).ListItem.Label']
                    rpc('Input.Select')
                    deadline = time.monotonic() + 8
                    while not rpc('XBMC.GetInfoBooleans', {'booleans': [info_window]}).get(info_window):
                        if time.monotonic() >= deadline:
                            raise RuntimeError('Selecting a game did not open its inspector')
                        time.sleep(0.1)
                    if rpc('Player.GetActivePlayers'):
                        raise RuntimeError('Opening the game inspector started playback')
                    screenshot('game-inspector')
                    title_label = 'Window(Home).Property(LocalHome.GameInfo.Title)'
                    for key, name in [('F11', 'game-two-line-title'), ('F12', 'game-truncated-title')]:
                        subprocess.run(['xdotool', 'key', '--clearmodifiers', key], env=env, check=True)
                        time.sleep(0.3)
                        title = rpc('XBMC.GetInfoLabels', {'labels': [title_label]})[title_label]
                        if len(title.split('[CR]')) != 2 or (key == 'F12' and not title.endswith('…')):
                            raise RuntimeError('Inspector title wrapping/truncation failed: ' + title)
                        screenshot(name)
                    subprocess.run(['xdotool', 'key', '--clearmodifiers', 'F10'], env=env, check=True)
                    page_labels = ['Container(31103).NumPages', 'Container(31103).CurrentPage']
                    deadline = time.monotonic() + 8
                    while int(rpc('XBMC.GetInfoLabels', {'labels': page_labels}).get(page_labels[0]) or '0') < 2:
                        if time.monotonic() >= deadline:
                            raise RuntimeError('Long description did not become scrollable')
                        time.sleep(0.1)
                    expect_focus(31101)
                    if not rpc('XBMC.GetInfoBooleans', {'booleans': ['Control.IsVisible(30912)']}).get('Control.IsVisible(30912)'):
                        raise RuntimeError('Long description has no right-stick scroll prompt')
                    subprocess.run(['xdotool', 'key', '--clearmodifiers', 'F9'], env=env, check=True)
                    time.sleep(0.3)
                    if int(rpc('XBMC.GetInfoLabels', {'labels': page_labels})[page_labels[1]]) <= 1:
                        raise RuntimeError('Right-stick down key did not scroll the description')
                    expect_focus(31101)
                    screenshot('game-description-scrolled')
                    subprocess.run(['xdotool', 'key', '--clearmodifiers', 'F8'], env=env, check=True)
                    time.sleep(0.3)
                    if rpc('XBMC.GetInfoLabels', {'labels': page_labels})[page_labels[1]] != '1':
                        raise RuntimeError('Right-stick up key did not return to the first page')
                    expect_focus(31101)
                    print('PASS right-stick description scrolling preserves Play focus', flush=True)
                    rpc('Input.Back')
                    expect_focus(30122)
                    if rpc('XBMC.GetInfoLabels', {'labels': ['Container(30122).ListItem.Label']})['Container(30122).ListItem.Label'] != selected_game:
                        raise RuntimeError('Inspector Back lost the selected game')
                    print('PASS game context menu has only game actions: ' + str(labels), flush=True)
                    subprocess.run(['xdotool', 'key', '--clearmodifiers', 'Next'], env=env, check=True)
                    expect_focus(30110 if empty_home else 30111)
                    # Exercise the actual keyboard keys emitted by InputPlumber.
                    def press_bumper(key):
                        subprocess.run(['xdotool', 'key', '--clearmodifiers', key],
                                       env=env, check=True)
                    def expect_page(page):
                        expected = {'Home': 'home', 'Videos': 'videos', 'Programs': 'games'}[page]
                        deadline = time.monotonic() + 8
                        while True:
                            state = rpc('XBMC.GetInfoLabels', {'labels': ['Window(Home).Property(LocalHome.Page)']})
                            busy = rpc('XBMC.GetInfoBooleans', {'booleans': ['Window.IsVisible(busydialog)', 'Window.IsVisible(busydialognocancel)', 'Control.IsVisible(3012199)', 'Control.IsVisible(3012299)']})
                            if any(busy.values()):
                                raise RuntimeError('Page navigation exposed loading/empty UI: ' + str(busy))
                            if (state['Window(Home).Property(LocalHome.Page)'] or 'home') == expected:
                                return
                            if time.monotonic() >= deadline:
                                raise RuntimeError('Bumper did not switch to ' + page)
                            time.sleep(0.025)
                    # Home -> Videos -> Games -> Home, then the reverse cycle.
                    for key, pages in [('Next', ['Videos', 'Programs', 'Home']),
                                       ('Prior', ['Programs', 'Videos', 'Home'])]:
                        for page in pages:
                            press_bumper(key)
                            expect_page(page)
                            if page != 'Home':
                                expect_focus(30121 if page == 'Videos' else 30122)
                                screenshot('tabs-' + page.lower())
                    press_bumper('Next')
                    expect_page('Videos')
                    press_bumper('Next')
                    expect_page('Programs')
                    subprocess.run(['xdotool', 'key', '--clearmodifiers', 'BackSpace'], env=env, check=True)
                    expect_page('Home')
                    print('PASS bumpers cycle Home/Videos/Games both ways; Back returns Home', flush=True)
                if history is not None:
                    episodes = rpc('VideoLibrary.GetEpisodes', {'properties': ['playcount']})
                    migrated = {e['episodeid']: e['playcount'] for e in episodes.get('episodes', [])}
                    if history != migrated:
                        raise RuntimeError('Episode/watch-history migration changed the library')
                    print(f'PASS library migration preserved {len(history)} episode records and watch counts', flush=True)
                    if expected_skin == 'skin.theatre':
                        subprocess.run(['xdotool', 'key', '--clearmodifiers', 'F6'], env=env, check=True)
                        expect_focus(9100)
                        expect_prompts(True)
                        screenshot('settings')
                        rpc('Input.Back')
                        subprocess.run(['xdotool', 'key', '--clearmodifiers', 'F7'], env=env, check=True)
                        expect_focus(3110)
                        screenshot('power')
                        rpc('Input.Back')
                        rpc('GUI.ActivateWindow', {'window': 'home'})
                        print('PASS native Settings and static Power menu are navigable', flush=True)
                for filename in media:
                    rpc('Player.Open', {'item': {'file': str(Path(filename).resolve())},
                                        'options': {'resume': False}})
                    time.sleep(4)
                    if expected_skin == 'skin.theatre':
                        expect_prompts(False)
                    before = rpc('Player.GetProperties', {'playerid': 1, 'properties': ['time', 'speed']})
                    time.sleep(8)
                    after = rpc('Player.GetProperties', {'playerid': 1, 'properties': ['time', 'speed']})
                    def seconds(value):
                        t = value['time']
                        return t['hours'] * 3600 + t['minutes'] * 60 + t['seconds']
                    if after['speed'] != 1 or seconds(after) - seconds(before) < 5:
                        raise RuntimeError(f'Playback did not advance: {before} -> {after}')
                    if expected_skin:
                        # Use actual keyboard events: JSON-RPC Input.Back skips
                        # window-specific keymaps, unlike our mapped gamepad.
                        def key(name):
                            subprocess.run(['xdotool', 'key', name], env=env, check=True, timeout=5)
                            time.sleep(0.35)  # Let native dialog-close animations finish.
                        key('Return')
                        if rpc('Player.GetProperties', {'playerid': 1, 'properties': ['speed']})['speed'] != 0:
                            raise RuntimeError('A did not pause directly from fullscreen playback')
                        key('Return')
                        if rpc('Player.GetProperties', {'playerid': 1, 'properties': ['speed']})['speed'] != 1:
                            raise RuntimeError('A did not resume directly from fullscreen playback')
                        seek_before = seconds(rpc('Player.GetProperties', {'playerid': 1, 'properties': ['time']}))
                        key('Right')
                        time.sleep(1)
                        seek_after = seconds(rpc('Player.GetProperties', {'playerid': 1, 'properties': ['time']}))
                        if seek_after - seek_before < 8:
                            raise RuntimeError('Right did not scrub forward')
                        key('Left')
                        time.sleep(1)
                        seek_back = seconds(rpc('Player.GetProperties', {'playerid': 1, 'properties': ['time']}))
                        if seek_after - seek_back < 6:
                            raise RuntimeError('Left did not scrub backward')
                        print('PASS A pauses/resumes directly; left/right scrub in fullscreen', flush=True)
                        key('Down')
                        time.sleep(0.5)
                        osd = 'Window.IsActive(VideoOSD)'
                        if not rpc('XBMC.GetInfoBooleans', {'booleans': [osd]}).get(osd):
                            raise RuntimeError('Select did not open the compact player controls')
                        expect_prompts(True)
                        if not rpc('XBMC.GetInfoBooleans', {'booleans': ['Control.IsVisible(30902)']}).get('Control.IsVisible(30902)'):
                            raise RuntimeError('Playback controls lost their A Select prompt')
                        screenshot('player-controls')
                        key('space')
                        time.sleep(0.3)
                        if rpc('Player.GetProperties', {'playerid': 1, 'properties': ['speed']})['speed'] != 0:
                            raise RuntimeError('Controller play/pause failed in the playback bar')
                        key('BackSpace')
                        time.sleep(0.3)
                        if rpc('XBMC.GetInfoBooleans', {'booleans': [osd]}).get(osd) or not rpc('Player.GetActivePlayers'):
                            raise RuntimeError('Back from controls should hide them, not stop video')
                        key('space')
                        print('PASS compact controls open, pause and dismiss without exiting playback', flush=True)
                        key('Down')
                        key('Return')
                        time.sleep(0.4)
                        audio = 'Window.IsActive(osdaudiosettings)'
                        if not rpc('XBMC.GetInfoBooleans', {'booleans': [audio]}).get(audio):
                            raise RuntimeError('Audio button did not open native audio settings')
                        time.sleep(6)
                        if not rpc('XBMC.GetInfoBooleans', {'booleans': [audio]}).get(audio):
                            raise RuntimeError('Playback bar auto-hide dismissed the audio dialog')
                        key('BackSpace')
                        key('Down')
                        key('Return')
                        time.sleep(0.4)
                        subtitles = 'Window.IsActive(osdsubtitlesettings)'
                        if not rpc('XBMC.GetInfoBooleans', {'booleans': [subtitles]}).get(subtitles):
                            raise RuntimeError('Subtitles button did not open native subtitle settings')
                        key('BackSpace')
                        time.sleep(6)
                        if rpc('XBMC.GetInfoBooleans', {'booleans': [osd]}).get(osd):
                            raise RuntimeError('Idle playback controls did not auto-hide')
                        expect_prompts(False)
                        print('PASS audio/subtitle dialogs usable; idle playback controls and prompts auto-hide', flush=True)
                        episode_items = rpc('VideoLibrary.GetEpisodes', {'properties': ['file', 'tvshowid']}).get('episodes', [])
                        matching = next((e for e in episode_items if e['file'] == str(Path(filename).resolve())), None)
                        if matching:
                            # Resume through the real Continue click action,
                            # not a direct file launch with no episode parent.
                            rpc('Input.Home')
                            time.sleep(0.8)
                            for _ in range(6):
                                if rpc('XBMC.GetInfoBooleans', {'booleans': ['Control.HasFocus(30111)']}).get('Control.HasFocus(30111)'):
                                    break
                                rpc('Input.Down')
                                time.sleep(0.2)
                            rpc('Input.ExecuteAction', {'action': 'firstpage'})
                            key('Return')
                            deadline = time.monotonic() + 8
                            while not rpc('Player.GetActivePlayers'):
                                if time.monotonic() >= deadline:
                                    raise RuntimeError('Continue did not resume an episode')
                                time.sleep(0.1)
                            time.sleep(1)
                            resumed = rpc('Player.GetItem', {
                                'playerid': 1, 'properties': ['tvshowid']})['item']
                            if resumed['type'] != 'episode' or resumed.get('tvshowid', -1) < 0:
                                raise RuntimeError('Continue did not resume a native episode: ' + str(resumed))
                            parent = 'Window.Previous(Videos)'
                            if not rpc('XBMC.GetInfoBooleans', {'booleans': [parent]}).get(parent):
                                raise RuntimeError('Continue started playback without preparing the episode parent')
                            key('BackSpace')
                            deadline = time.monotonic() + 8
                            checks = ['Container.Content(episodes)', 'Window.IsActive(Videos)']
                            while not all(rpc('XBMC.GetInfoBooleans', {'booleans': checks}).values()) or rpc('Player.GetActivePlayers'):
                                if time.monotonic() >= deadline:
                                    raise RuntimeError('Episode Back failed to stop and open the native episode list')
                                time.sleep(0.1)
                            path = rpc('XBMC.GetInfoLabels', {'labels': ['Container.FolderPath']})['Container.FolderPath']
                            if f"/{resumed['tvshowid']}/" not in path:
                                raise RuntimeError('Episode Back opened the wrong show: ' + path)
                            screenshot('player-back-episodes')
                            print('PASS episode launched directly from Home exits to its own native episode list', flush=True)
                            rpc('Player.Open', {'item': {'episodeid': matching['episodeid']}})
                            time.sleep(2)
                        rpc('Input.Home')
                        deadline = time.monotonic() + 5
                        while rpc('Player.GetActivePlayers'):
                            if time.monotonic() >= deadline:
                                raise RuntimeError('Returning Home left playback running')
                            time.sleep(0.1)
                        print('PASS returning Home stopped playback', flush=True)
                    else:
                        rpc('Player.Stop', {'playerid': 1})
                    print(f'PASS playback advanced: {Path(filename).name}', flush=True)
                rpc('Application.Quit')
            kodi.wait(timeout=15)
            log = (base / 'profile/temp/kodi.log').read_text(errors='replace')
            if ('StateMachine - signal' in log or 'could not create stream' in log
                    or 'ActiveAE::OnLostDisplay - timed out' in log):
                raise RuntimeError('Audio failure/busy loop in Kodi log')
            if 'CAESinkPipewire::Initialize' not in log:
                raise RuntimeError('No evidence of native PipeWire initialization')
            if 'PythonToCppException' in log or 'Local Home: source configuration timed out' in log:
                raise RuntimeError('Add-on failure in Kodi log')
            if expected_skin and 'Local Home: configured local-only media sources' not in log:
                raise RuntimeError('Local Home service did not configure the migrated library')
            print('PASS native PipeWire initialized; no audio busy-loop warnings', flush=True)
        except Exception:
            try:
                screenshot('failure')
            except Exception:
                pass
            for path in (base / 'stdout.log', base / 'profile/temp/kodi.log'):
                if path.exists():
                    if os.environ.get('KODI_TEST_ARTIFACTS'):
                        destination = Path(os.environ['KODI_TEST_ARTIFACTS'])
                        destination.mkdir(parents=True, exist_ok=True)
                        shutil.copyfile(path, destination / path.name)
                    print(path.read_text(errors='replace')[-8000:], file=sys.stderr)
            raise
        finally:
            os.close(readfd)
            if kodi is not None:
                subprocess.run(['systemctl', '--user', 'stop', scope],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
                stop(kodi)
            stop(display)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--userdata', type=Path, help='copy a stopped/backed-up profile to test migration')
    parser.add_argument('--skin', help='assert the configured skin did not fall back')
    parser.add_argument('binary')
    parser.add_argument('media', nargs='+')
    args = parser.parse_args()
    main(args.binary, args.media, args.userdata, args.skin)
