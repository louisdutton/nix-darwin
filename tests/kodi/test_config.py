"""Regression checks for deployment and local-only source configuration."""
import importlib.util
import hashlib
import json
import os
import select
import signal
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
import time
import types
import unittest
from unittest import mock
import xml.etree.ElementTree as ET

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


prepare_module = load_module('prepare', ROOT / 'pkgs/kodi/prepare.py')
audio_ready = load_module('audio_ready', ROOT / 'pkgs/kodi/audio_ready.py')
peripheral_patch = load_module('peripheral_patch', ROOT / 'pkgs/kodi/patch_peripherals.py')
video_controls = load_module('video_controls', ROOT / 'config/kodi/localhome/video_controls.py')
navigation = load_module('navigation', ROOT / 'config/kodi/localhome/navigation.py')
openbox_patch = load_module('openbox_patch', ROOT / 'pkgs/kodi/patch_openbox.py')
sys.modules.setdefault('xbmc', types.ModuleType('xbmc'))
sys.modules.setdefault('xbmcvfs', types.ModuleType('xbmcvfs'))
service = load_module('localhome_service', ROOT / 'config/kodi/localhome/service.py')
sys.modules.setdefault('xbmcgui', types.ModuleType('xbmcgui'))
continue_watching = load_module('continue_watching', ROOT / 'config/kodi/localhome/continue_watching.py')
sys.modules['continue_watching'] = continue_watching
sys.modules.setdefault('xbmcplugin', types.ModuleType('xbmcplugin'))
game_session = load_module('game_session', ROOT / 'config/kodi/localhome/game_session.py')
sys.modules['game_session'] = game_session
gamescope = load_module('gamescope', ROOT / 'config/kodi/localhome/gamescope.py')
sys.modules['gamescope'] = gamescope
standalone = load_module('standalone', ROOT / 'config/kodi/localhome/standalone.py')
sys.modules['standalone'] = standalone
owned_launch = load_module('owned_launch', ROOT / 'config/kodi/localhome/owned_launch.py')
sys.modules['owned_launch'] = owned_launch
launcher = load_module('localhome_launcher', ROOT / 'config/kodi/localhome/default.py')
game_manager = load_module('game_manager', ROOT / 'config/kodi/localhome/game_manager.py')
session_home = load_module('session_home', ROOT / 'config/kodi/localhome/session_home.py')
sys.modules['session_home'] = session_home
input_router = load_module('input_router', ROOT / 'config/kodi/localhome/input_router.py')
sys.modules['input_router'] = input_router
gog_cli = load_module('gog_cli', ROOT / 'pkgs/gog/gog.py')


class GameMetadataTests(unittest.TestCase):
    def test_official_overview_is_plain_text_and_cached_offline(self):
        response = mock.MagicMock()
        response.__enter__.return_value.read.return_value = json.dumps({
            'description': {'lead': '<img src="logo.png"><br><br>Demo version is available here.<br><hr><br><p><b>Explore</b> &amp; discover a mysterious world filled with secrets.</p><video>Trailer</video><h4>Features</h4>'}
        })
        with mock.patch.object(gog_cli, 'urlopen', return_value=response) as request:
            game = gog_cli.cache_description({'id': '123', 'title': 'Game'})
            self.assertEqual(game['description'], 'Explore & discover a mysterious world filled with secrets.')
            self.assertEqual(gog_cli.cache_description(game), game)
            request.assert_called_once()

    def test_metadata_failure_preserves_inventory_and_artwork(self):
        games = [{'id': '123', 'art_square': '/cached/cover'}, {'id': '456', 'description': 'Existing'}]
        with tempfile.TemporaryDirectory() as temporary, \
                mock.patch.object(gog_cli, 'state_dir', return_value=Path(temporary)), \
                mock.patch.object(gog_cli, 'cache_artwork', side_effect=lambda item: item), \
                mock.patch.object(gog_cli, 'urlopen', side_effect=OSError('offline')):
            self.assertEqual(gog_cli.refresh_metadata(games), games)
            self.assertEqual(json.loads((Path(temporary) / 'library.json').read_text()), games)


class GameLaunchTests(unittest.TestCase):
    def test_inspector_titles_are_limited_to_two_lines_with_ellipsis(self):
        self.assertEqual(launcher.wrap_inspector_title('Short title', len, 12), 'Short title')
        self.assertEqual(launcher.wrap_inspector_title('One title on two lines', len, 12), 'One title on[CR]two lines')
        for title in ('An unusually long game title with several extra words', 'W' * 40 + ' Other words'):
            lines = launcher.wrap_inspector_title(title, len, 12).split('[CR]')
            self.assertLessEqual(len(lines), 2)
            self.assertTrue(any(line.endswith('…') for line in lines))
            self.assertTrue(all(len(line) <= 12 for line in lines))

    def test_game_info_action_keeps_game_tag_without_video_actions(self):
        item = mock.Mock()
        launcher.game_item_info(item, 'Game', 'Description', 'gog:123')
        item.addContextMenuItems.assert_called_once_with([
            ('More info', 'RunScript(' + str(ROOT / 'config/kodi/localhome/default.py') + ',info,gog:123)'),
            ('Uninstall', 'RunScript(' + str(ROOT / 'config/kodi/localhome/game_manager.py') + ',uninstall,gog:123)')])
        item.setInfo.assert_not_called()

    def test_game_info_opens_local_details_without_launching(self):
        with mock.patch.object(launcher.xbmcgui, 'Window', create=True) as window:
            launcher.show_game_info('123')
            properties = dict(call.args for call in window.return_value.setProperty.call_args_list)
            self.assertEqual(properties['LocalHome.GameInfo.Title'], 'Test game')
            self.assertEqual(properties['LocalHome.GameInfo.Action'], 'Launch')
            launcher.xbmc.executebuiltin.assert_called_once_with('ActivateWindow(11100)')

    def test_game_actions_are_not_videos_or_playable_media(self):
        item = mock.Mock()
        launcher.game_item_info(item, 'Game', 'Installed locally.')
        item.getGameInfoTag().setTitle.assert_called_once_with('Game')
        item.getGameInfoTag().setOverview.assert_called_once_with('Installed locally.')
        item.setProperty.assert_called_once_with('IsPlayable', 'false')
        item.setInfo.assert_not_called()

    def test_installed_games_sort_first_then_alphabetically(self):
        games = {'uninstalled-a': {'title': 'A', 'installed': False},
                 'installed-z': {'title': 'Z', 'installed': True},
                 'standalone-b': {'title': 'b'},
                 'uninstalled-c': {'title': 'C', 'installed': False}}
        self.assertEqual([key for key, _ in launcher.sorted_games(games)],
                         ['standalone-b', 'installed-z', 'uninstalled-a', 'uninstalled-c'])

    def setUp(self):
        self.dialog = mock.Mock()
        for patcher in [
                mock.patch.object(launcher, 'installed_games', return_value={'123': 'Test game'}),
                mock.patch.object(launcher, 'game_catalog', return_value={'123': {'title': 'Test game', 'source': 'Standalone (native)', 'command': ['/trusted/runtime', '/installed/game']}}),
                mock.patch.object(launcher, 'local_art', return_value={}),
                mock.patch.object(launcher, 'inspector_title', side_effect=lambda title: title),
                mock.patch.object(launcher, 'run_game', side_effect=lambda appid, game, spawn: (spawn(), True)[1]),
                mock.patch.object(launcher.xbmcgui, 'Dialog', return_value=self.dialog, create=True),
                mock.patch.object(launcher.xbmc, 'executebuiltin', create=True),
                mock.patch.object(launcher.xbmc, 'log', create=True),
                mock.patch.object(launcher.xbmc, 'LOGERROR', 4, create=True)]:
            patcher.start()
            self.addCleanup(patcher.stop)

    def test_launch_preserves_display_and_does_not_quit_kodi(self):
        with mock.patch.object(launcher, 'OwnedLaunch') as spawn:
            self.assertTrue(launcher.launch_game('123', supervised=True))
        args, kwargs = spawn.call_args
        self.assertEqual(args[0]['command'], ['/trusted/runtime', '/installed/game'])
        self.assertNotIn('shell', kwargs)
        launcher.xbmc.executebuiltin.assert_not_called()
        self.dialog.yesno.assert_not_called()

    def test_invalid_or_uninstalled_ids_do_not_spawn(self):
        with mock.patch.object(launcher.subprocess, 'Popen') as spawn:
            for appid in ('999', '123; touch /tmp/bad', '../game', '-123'):
                self.assertFalse(launcher.launch_game(appid))
        spawn.assert_not_called()

    def test_launch_failure_leaves_kodi_running(self):
        with mock.patch.object(launcher, 'OwnedLaunch', side_effect=OSError('test failure')):
            self.assertFalse(launcher.launch_game('123', supervised=True))
        launcher.xbmc.executebuiltin.assert_not_called()
        self.dialog.notification.assert_called_with('Games', 'Could not start Standalone (native)')


    def test_widget_dispatches_validated_id_to_supervised_script(self):
        with mock.patch.object(launcher.subprocess, 'Popen') as spawn:
            self.assertTrue(launcher.launch_game('123'))
        spawn.assert_not_called()
        launcher.xbmc.executebuiltin.assert_called_once_with(
            'RunScript(' + str(ROOT / 'config/kodi/localhome/game_session.py') + ',123)')


class StandaloneTests(unittest.TestCase):
    def test_custom_checkout_launch_uses_live_task_and_clean_environment(self):
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            checkout = home / 'projects/hollie'
            checkout.mkdir(parents=True)
            executable = home / 'devenv'
            executable.touch()
            declaration = {'workingDirectory': 'projects/hollie',
                           'command': [str(executable), 'tasks', 'run', 'hollie:run']}
            with mock.patch.dict(os.environ, {'LD_PRELOAD': 'old-overlay', 'LD_LIBRARY_PATH': 'old-runtime',
                                             'STEAM_RUNTIME_LIBRARY_PATH': 'old-steam', 'DISPLAY': ':42'}):
                game = standalone.custom_launch(declaration, home)
            self.assertEqual(game['command'], declaration['command'])
            self.assertEqual(game['cwd'], str(checkout))
            self.assertEqual(game['install_path'], str(checkout))
            self.assertEqual(game['environment']['DISPLAY'], ':42')
            self.assertNotIn('LD_PRELOAD', game['environment'])
            self.assertNotIn('LD_LIBRARY_PATH', game['environment'])
            self.assertNotIn('STEAM_RUNTIME_LIBRARY_PATH', game['environment'])
            self.assertNotIn('steam_appid', game)
            self.assertEqual(game['environment']['SDL_GAMECONTROLLER_IGNORE_DEVICES'], '0x057e/0x2009')
            declaration['workingDirectory'] = 'missing-checkout'
            with self.assertRaisesRegex(RuntimeError, 'checkout is missing'):
                standalone.custom_launch(declaration, home)

    def test_custom_game_is_available_without_a_steam_install(self):
        declaration = {'title': 'Hollie', 'description': 'Development checkout'}
        with mock.patch.object(launcher, 'installed_games', return_value={}), \
                mock.patch.object(launcher, 'installed_steam_records', return_value={}), \
                mock.patch.object(launcher, 'read_json', return_value={'custom:hollie': declaration}), \
                mock.patch.object(launcher, 'local_art', return_value={}), \
                mock.patch.object(launcher, 'owned_gog_games', return_value={}), \
                mock.patch.object(launcher, 'installed_gog_games', return_value={}), \
                mock.patch.object(launcher, 'custom_launch', return_value={'command': ['/trusted/devenv'], 'installed': True}) as custom:
            game = launcher.game_catalog()['custom:hollie']
            self.assertEqual(game['title'], 'Hollie')
            self.assertTrue(game['installed'])
            self.assertNotIn('launch_error', game)
            custom.assert_called_once_with(declaration)
            custom.side_effect = RuntimeError('checkout missing')
            self.assertEqual(launcher.game_catalog()['custom:hollie']['launch_error'], 'checkout missing')

    def test_managed_proton_is_used_without_heroic_runner(self):
        with tempfile.TemporaryDirectory() as temporary:
            install = Path(temporary)
            (install / 'game.exe').touch()
            (install / 'managed-proton').mkdir()
            (install / 'managed-proton/proton').touch()
            tools = {'umu': '/trusted/umu-run', 'proton': str(install / 'managed-proton')}
            config = standalone.launch_config('123', {'executable': 'game.exe'}, install, install / 'Steam', tools, install)
            self.assertEqual(config['environment']['PROTONPATH'], tools['proton'])
            record = {'install_path': str(install), 'executable': str(install / 'game.exe'), 'prefix': '/preserved/prefix', 'arguments': ['--test']}
            game = standalone.gog_launch(record, tools)
            self.assertEqual(game['command'], ['/trusted/umu-run', str(install / 'game.exe'), '--test'])
            self.assertEqual(game['environment']['WINEPREFIX'], '/preserved/prefix')
            self.assertNotIn('steam_appid', game)

    def test_declared_launcher_clears_unconfigured_error(self):
        with mock.patch.object(launcher, 'installed_games', return_value={'123': 'Declared game'}), \
                mock.patch.object(launcher, 'read_json', return_value={'123': {'executable': 'game', 'title': 'Custom title', 'description': 'Official overview'}}), \
                mock.patch.object(launcher, 'installed_steam_records', return_value={'123': {'path': '/installed'}}), \
                mock.patch.object(launcher, 'launch_config', return_value={'command': ['/trusted/runtime', '/installed/game'], 'source': 'Standalone (native)'}), \
                mock.patch.object(launcher, 'local_art', return_value={}):
            game = launcher.game_catalog()['123']
        self.assertNotIn('launch_error', game)
        self.assertEqual(game['command'], ['/trusted/runtime', '/installed/game'])
        self.assertEqual(game['title'], 'Custom title')
        self.assertEqual(game['description'], 'Official overview')

    def test_undeclared_game_has_no_steam_fallback(self):
        with mock.patch.object(launcher, 'installed_games', return_value={'123': 'Unknown game'}), \
                mock.patch.object(launcher, 'read_json', return_value={}), \
                mock.patch.object(launcher, 'local_art', return_value={}):
            game = launcher.game_catalog()['123']
        self.assertIn('launch_error', game)
        self.assertNotIn('command', game)

    def test_native_runner_does_not_require_proton(self):
        with tempfile.TemporaryDirectory() as temporary:
            install = Path(temporary)
            (install / 'game').touch()
            config = standalone.launch_config('123', {'runner': 'native', 'executable': 'game'}, install,
                                              install / 'Steam', {'steam-run': '/trusted/steam-run'}, install)
            self.assertEqual(config['command'], ['/trusted/steam-run', str(install / 'game')])
            standalone.prepare_game(config)
            self.assertEqual((install / 'steam_appid.txt').read_text(), '123\n')
            standalone.prepare_game(config)
            (install / 'steam_appid.txt').write_text('456\n')
            with self.assertRaises(RuntimeError):
                standalone.prepare_game(config)

    def test_independent_command_never_invokes_steam(self):
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            install = home / 'installed'
            install.mkdir()
            (install / 'game.exe').touch()
            (home / 'proton').mkdir()
            (home / 'proton/proton').touch()
            declaration = {'executable': 'game.exe', 'prefix': 'prefix',
                           'proton': 'proton', 'saveDirectory': 'saves'}
            config = standalone.launch_config('123', declaration, install, home / 'Steam', {'umu': '/trusted/umu-run'}, home)
            self.assertEqual(config['command'], ['/trusted/umu-run', str(install / 'game.exe')])
            self.assertEqual(config['environment']['GAMEID'], '0')
            self.assertEqual(config['environment']['SteamAppId'], '123')
            self.assertEqual(config['cwd'], str(install))
            declaration['executable'] = '../outside.exe'
            (home / 'outside.exe').touch()
            with self.assertRaises(RuntimeError):
                standalone.launch_config('123', declaration, install, home / 'Steam', {'umu': '/trusted/umu-run'}, home)

    def test_save_migration_never_overwrites_progress_or_copies_code(self):
        with tempfile.TemporaryDirectory() as temporary:
            source, target = Path(temporary) / 'source', Path(temporary) / 'target'
            source.mkdir()
            target.mkdir()
            (source / 'user1.dat').write_bytes(b'old progress')
            (source / 'user2.dat').write_bytes(b'other save')
            (source / 'untrusted.exe').write_bytes(b'not a save')
            (source / 'user3.dat').symlink_to(source / 'untrusted.exe')
            (target / 'user1.dat').write_bytes(b'new progress')
            standalone.import_saves({'save_source': str(source), 'save_target': str(target)})
            self.assertEqual((target / 'user1.dat').read_bytes(), b'new progress')
            self.assertEqual((target / 'user2.dat').read_bytes(), b'other save')
            self.assertFalse((target / 'untrusted.exe').exists())
            self.assertFalse((target / 'user3.dat').exists())
            self.assertEqual((source / 'user1.dat').read_bytes(), b'old progress')

    def test_standalone_launch_prepares_saves_and_preserves_environment(self):
        game = {'title': 'Test', 'source': 'Standalone (UMU)',
                'command': ['/trusted/umu-run', '/installed/game.exe'],
                'environment': {'GAMEID': '0'}, 'cwd': '/installed'}
        with mock.patch.object(launcher, 'game_catalog', return_value={'123': game}), \
                mock.patch.object(launcher, 'prepare_game') as saves, \
                mock.patch.object(launcher, 'run_game', side_effect=lambda appid, game, spawn: (spawn(), True)[1]), \
                mock.patch.object(launcher, 'OwnedLaunch') as spawn:
            self.assertTrue(launcher.launch_game('123', supervised=True))
            saves.assert_called_once_with(game)
            self.assertEqual(spawn.call_args.args[0]['environment'], {'GAMEID': '0'})
            self.assertEqual(spawn.call_args.args[0]['cwd'], '/installed')


class GameSessionTests(unittest.TestCase):
    def check_cleanup(self, cancelled=False, exited=False, timeout=False, broken=False):
        home, progress, monitor, launch = mock.Mock(), mock.Mock(), mock.Mock(), mock.Mock()
        home.getProperty.return_value = ''
        progress.iscanceled.return_value = cancelled
        monitor.abortRequested.return_value = False
        monitor.waitForAbort.return_value = False
        launch.poll.return_value = 1 if exited else None
        launch.log_path = '/private/launch.log'
        before = {'1': {'class': '"kodi", "Kodi"'}}
        with mock.patch.object(game_session.xbmcgui, 'Window', return_value=home, create=True), \
                mock.patch.object(game_session.xbmcgui, 'DialogProgress', return_value=progress, create=True), \
                mock.patch.object(game_session.xbmcgui, 'Dialog', create=True) as dialog, \
                mock.patch.object(game_session.xbmc, 'Monitor', return_value=monitor, create=True), \
                mock.patch.object(game_session.xbmc, 'log', create=True), \
                mock.patch.object(game_session.xbmc, 'LOGERROR', 4, create=True), \
                mock.patch.object(game_session.xbmc, 'LOGWARNING', 3, create=True), \
                mock.patch.object(continue_watching, 'record_game') as record, \
                mock.patch.object(game_session, 'command'), \
                mock.patch.object(game_session, 'windows', side_effect=[before, OSError('window query failed')] if broken else None, return_value=before):
            if broken:
                # Query failure retries, while the startup deadline still bounds it.
                with mock.patch.object(game_session.time, 'monotonic', side_effect=[0, 0, 151]):
                    self.assertFalse(game_session.run_game('123', {'title': 'Test', 'source': 'Standalone'}, lambda: launch))
            else:
                self.assertFalse(game_session.run_game('123', {'title': 'Test', 'source': 'Standalone'}, lambda: launch, timeout=0 if timeout else 150))
            if cancelled:
                dialog.return_value.notification.assert_not_called()
            record.assert_not_called()
        launch.stop.assert_called_once()
        home.clearProperty.assert_called_once_with('LocalHome.GamePending')

    def test_cancel_terminates_owned_launch_without_old_notification(self):
        self.check_cleanup(cancelled=True)

    def test_timeout_terminates_owned_launch(self):
        self.check_cleanup(timeout=True)

    def test_early_exit_cleans_up_children(self):
        self.check_cleanup(exited=True)

    def test_persistent_window_query_failure_still_times_out_and_cleans_up(self):
        self.check_cleanup(broken=True)

    def test_transient_x11_failures_do_not_stop_a_running_game(self):
        for failure in ('query', 'focus', 'running-query'):
            with self.subTest(failure=failure):
                home, progress, monitor, launch = mock.Mock(), mock.Mock(), mock.Mock(), mock.Mock()
                home.getProperty.return_value = ''
                progress.iscanceled.return_value = False
                monitor.abortRequested.return_value = False
                launch.poll.return_value = None
                before = {'1': {'class': '"kodi", "Kodi"'}}
                timeout = subprocess.TimeoutExpired('xprop', 3)
                snapshots = ([before, timeout, before] if failure == 'query' else
                             [before, before, timeout, before] if failure == 'running-query' else
                             [before, before, before])
                monitor.waitForAbort.side_effect = [False, False, True] if failure == 'running-query' else [False, True]
                activations = [subprocess.CalledProcessError(1, 'xdotool'), None, None] if failure == 'focus' else None
                with mock.patch.object(game_session.xbmcgui, 'Window', return_value=home, create=True), \
                        mock.patch.object(game_session.xbmcgui, 'DialogProgress', return_value=progress, create=True), \
                        mock.patch.object(game_session.xbmc, 'Monitor', return_value=monitor, create=True), \
                        mock.patch.object(game_session.xbmc, 'log', create=True), \
                        mock.patch.object(game_session.xbmc, 'LOGWARNING', 3, create=True), \
                        mock.patch.object(game_session, 'windows', side_effect=snapshots), \
                        mock.patch.object(game_session, 'find_game', return_value='2'), \
                        mock.patch.object(game_session, 'command', side_effect=activations) as command, \
                        mock.patch.object(continue_watching, 'record_game') as record, \
                        mock.patch.object(continue_watching, 'refresh'):
                    self.assertTrue(game_session.run_game('custom:hollie', {'title': 'Hollie'}, lambda: launch))
                    record.assert_called_once_with('custom:hollie')
                    command.assert_any_call('xdotool', 'windowactivate', '2')
                launch.stop.assert_called_once()
                home.clearProperty.assert_called_once_with('LocalHome.GamePending')

    def test_failed_spawn_closes_progress_and_releases_launch_lock(self):
        home, progress, monitor = mock.Mock(), mock.Mock(), mock.Mock()
        home.getProperty.return_value = ''
        with mock.patch.object(game_session.xbmcgui, 'Window', return_value=home, create=True), \
                mock.patch.object(game_session.xbmcgui, 'DialogProgress', return_value=progress, create=True), \
                mock.patch.object(game_session.xbmc, 'Monitor', return_value=monitor, create=True), \
                mock.patch.object(game_session, 'windows', return_value={}):
            with self.assertRaises(OSError):
                game_session.run_game('123', {'title': 'Test'}, mock.Mock(side_effect=OSError('failed')))
        progress.close.assert_called_once()
        home.clearProperty.assert_called_once_with('LocalHome.GamePending')


    def test_progress_closes_before_focus_and_kodi_focus_restores_on_exit(self):
        events = []
        home, progress, monitor = mock.Mock(), mock.Mock(), mock.Mock()
        home.getProperty.return_value = ''
        progress.iscanceled.return_value = False
        progress.close.side_effect = lambda: events.append('close')
        monitor.abortRequested.return_value = False
        monitor.waitForAbort.return_value = True
        before = {'1': {'class': '"kodi", "Kodi"'}}
        game = {'source': 'Standalone (native)', 'title': 'Test'}
        with mock.patch.object(game_session.xbmcgui, 'Window', return_value=home, create=True), \
                mock.patch.object(game_session.xbmcgui, 'DialogProgress', return_value=progress, create=True), \
                mock.patch.object(game_session.xbmc, 'Monitor', return_value=monitor, create=True), \
                mock.patch.object(game_session, 'windows', side_effect=[before, before]), \
                mock.patch.object(game_session, 'find_game', return_value='2'), \
                mock.patch.object(game_session, 'command', side_effect=lambda *args: events.append(args)), \
                mock.patch.object(continue_watching, 'record_game') as record, \
                mock.patch.object(continue_watching, 'refresh'):
            launch = mock.Mock()
            launch.poll.return_value = None
            self.assertTrue(game_session.run_game('123', game, lambda: events.append('spawn') or launch))
            record.assert_called_once_with('123')
            launch.stop.assert_called_once()
        self.assertLess(events.index('close'), events.index(('xdotool', 'windowactivate', '2')))
        self.assertEqual(events[-1], ('xdotool', 'windowactivate', '1'))
        home.clearProperty.assert_called_once_with('LocalHome.GamePending')

    def test_duplicate_launch_is_rejected(self):
        home = mock.Mock()
        home.getProperty.return_value = '123'
        with mock.patch.object(game_session.xbmcgui, 'Window', return_value=home, create=True), \
                mock.patch.object(game_session.xbmcgui, 'Dialog', create=True):
            spawn = mock.Mock()
            self.assertFalse(game_session.run_game('123', {'title': 'Test'}, spawn))
            spawn.assert_not_called()


@unittest.skipUnless(os.environ.get('KODI_LAUNCH_INTEGRATION') == '1', 'requires a live systemd user manager')
class OwnedLaunchIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.tools = {'python': sys.executable,
                      'systemd-run': '/run/current-system/sw/bin/systemd-run',
                      'systemctl': '/run/current-system/sw/bin/systemctl'}

    def start(self, code):
        launch = owned_launch.OwnedLaunch({'command': [sys.executable, '-u', '-c', code]}, self.tools)
        self.addCleanup(launch.stop)
        for _ in range(50):
            text = launch.log_path.read_text()
            if 'PIDS ' in text:
                return launch, list(map(int, text.split('PIDS ')[1].splitlines()[0].split()))
            if launch.poll() is not None:
                self.fail('Owned service failed: ' + text)
            time.sleep(0.1)
        self.fail('Test service did not start')

    def test_stop_kills_detached_child_even_if_it_ignores_sigterm(self):
        child = 'import signal,time;signal.signal(signal.SIGTERM,signal.SIG_IGN);time.sleep(120)'
        code = 'import subprocess,time,os;c=subprocess.Popen(' + repr([sys.executable, '-c', child]) + ',start_new_session=True);time.sleep(.3);print("PIDS",os.getpid(),c.pid,flush=True);time.sleep(120)'
        launch, pids = self.start(code)
        launch.stop()
        self.assertTrue(all(not Path('/proc', str(pid)).exists() for pid in pids))

    def test_launcher_exit_does_not_lose_ownership_of_child(self):
        launch, pids = self.start('import subprocess,os;c=subprocess.Popen(["/run/current-system/sw/bin/sleep","120"],start_new_session=True);print("PIDS",os.getpid(),c.pid,flush=True)')
        time.sleep(.3)
        self.assertIsNone(launch.poll())
        launch.stop()
        self.assertFalse(Path('/proc', str(pids[1])).exists())

    def test_owner_death_ends_service(self):
        code = ('import sys,time;sys.path.insert(0,' + repr(str(ROOT / 'config/kodi/localhome')) + ');'
                'from owned_launch import OwnedLaunch;'
                'launch=OwnedLaunch({"command":["/run/current-system/sw/bin/sleep","120"]},' + repr(self.tools) + ');'
                'print(launch.unit,flush=True);time.sleep(.5)')
        with subprocess.Popen([sys.executable, '-c', code], stdout=subprocess.PIPE, text=True) as parent:
            unit = parent.stdout.readline().strip()
            parent.wait(timeout=5)
        for _ in range(40):
            result = subprocess.run([self.tools['systemctl'], '--user', 'show', unit, '-p', 'ActiveState', '--value'], capture_output=True, text=True, timeout=3)
            if result.returncode or result.stdout.strip() in ('inactive', 'failed'):
                break
            time.sleep(.1)
        else:
            subprocess.run([self.tools['systemctl'], '--user', 'stop', unit], check=True)
            self.fail('Launch survived owner death')


class GameManagementTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.dialog = mock.Mock()
        self.dialog.yesno.return_value = True
        self.progress = mock.Mock()
        self.progress.iscanceled.return_value = False
        self.home = mock.Mock()
        self.home.getProperty.return_value = ''
        self.monitor = mock.Mock()
        self.monitor.waitForAbort.return_value = False
        self.monitor.abortRequested.return_value = False
        self.launch = mock.Mock()
        self.launch.poll.return_value = 0
        for patcher in [
                mock.patch.dict(sys.modules, {'default': launcher}),
                mock.patch.dict(os.environ, {'XDG_RUNTIME_DIR': temporary.name}),
                mock.patch.object(launcher, 'game_catalog', return_value={'gog:123': {'title': 'Test', 'installed': False}}),
                mock.patch.object(game_manager, 'TOOLS', {'gog': '/trusted/gog'}),
                mock.patch.object(game_manager, 'installation_estimate', return_value={
                    'download_bytes': 100 * 1024 * 1024, 'installed_bytes': 200 * 1024 * 1024,
                    'free_bytes': 10 * 1024**3}),
                mock.patch.object(game_manager, 'OwnedLaunch', return_value=self.launch),
                mock.patch.object(game_manager.xbmcgui, 'Window', return_value=self.home, create=True),
                mock.patch.object(game_manager.xbmcgui, 'Dialog', return_value=self.dialog, create=True),
                mock.patch.object(game_manager.xbmcgui, 'DialogProgress', return_value=self.progress, create=True),
                mock.patch.object(game_manager.xbmc, 'Monitor', return_value=self.monitor, create=True),
                mock.patch.object(game_manager.xbmc, 'executebuiltin', create=True)]:
            patcher.start()
            self.addCleanup(patcher.stop)

    def test_install_calls_pinned_cli_and_refreshes(self):
        self.assertTrue(game_manager.manage('install', 'gog:123'))
        argv = game_manager.OwnedLaunch.call_args.args[0]['command']
        self.assertEqual(argv[:4], ['/trusted/gog', 'install', '123', '--status-file'])
        self.assertIn('Download: 100.0 MiB', self.dialog.yesno.call_args.args[1])
        self.assertIn('Available space: 10.0 GiB', self.dialog.yesno.call_args.args[1])
        self.launch.stop.assert_called_once()
        self.progress.close.assert_called_once()
        game_manager.xbmc.executebuiltin.assert_called_with('Container.Refresh')

    def test_cancel_stops_all_owned_children(self):
        self.launch.poll.return_value = None
        self.progress.iscanceled.return_value = True
        self.assertFalse(game_manager.manage('install', 'gog:123'))
        self.launch.stop.assert_called_once()
        self.progress.close.assert_called_once()

    def test_missing_estimate_and_insufficient_space_never_install(self):
        game_manager.installation_estimate.return_value = None
        self.assertFalse(game_manager.manage('install', 'gog:123'))
        game_manager.installation_estimate.return_value = {'download_bytes': 100, 'installed_bytes': 200, 'free_bytes': 50}
        self.assertFalse(game_manager.manage('install', 'gog:123'))
        self.dialog.ok.assert_called_once()
        game_manager.OwnedLaunch.assert_not_called()

    def test_progress_uses_status_percentage_speed_and_eta(self):
        self.launch.poll.side_effect = [None, 0, 0]
        status = {'phase': 'installing', 'percent': 47.5, 'downloaded_bytes': 512 * 1024**2,
                  'download_bytes': 1024**3, 'speed_bytes': 10 * 1024**2, 'eta_seconds': 65}
        with mock.patch.object(game_manager, 'read_status', return_value=status):
            self.assertTrue(game_manager.execute_operation(['/trusted/gog'], 'Test', Path('/private/status'), 'install'))
        updates = self.progress.update.call_args_list
        self.assertEqual(updates[0].args[0], 47)
        self.assertIn('512.0 MiB / 1.0 GiB', updates[0].args[1])
        self.assertIn('10.0 MiB/s', updates[0].args[1])
        self.assertIn('00:01:05', updates[0].args[1])
        self.assertEqual(updates[-1].args[0], 100)
        self.launch.stop.assert_called_once()

    def test_eta_unknown_until_download_starts(self):
        self.assertIn('calculating', game_manager.progress_text({'phase': 'installing', 'percent': 0}))

    def test_running_game_and_declined_confirmation_never_spawn(self):
        self.home.getProperty.return_value = 'gog:999'
        self.assertFalse(game_manager.manage('install', 'gog:123'))
        self.home.getProperty.return_value = ''
        self.dialog.yesno.return_value = False
        self.assertFalse(game_manager.manage('install', 'gog:123'))
        game_manager.OwnedLaunch.assert_not_called()


class GogLibraryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.heroic = self.base / 'heroic'
        patcher = mock.patch.object(launcher, 'GOG', self.base / 'gog')
        patcher.start()
        self.addCleanup(patcher.stop)
        patcher = mock.patch.object(launcher, 'HEROIC', self.heroic)
        patcher.start()
        self.addCleanup(patcher.stop)
        patcher = mock.patch.object(launcher, 'ARTWORK_CACHE', self.base / 'artwork')
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_owned_gog_includes_uninstalled_without_launch_command(self):
        launcher.GOG.mkdir(parents=True)
        (launcher.GOG / 'library.json').write_text(json.dumps([{'id': '123', 'title': 'Owned game'}]))
        game = launcher.owned_gog_games()['gog:123']
        self.assertFalse(game['installed'])
        self.assertNotIn('command', game)
        self.assertEqual(game['title'], 'Owned game')


    def test_gog_uses_portrait_not_store_banner(self):
        game = {'art_cover': 'https://example.invalid/banner.jpg?namespace=gamesdb',
                'art_square': 'https://example.invalid/portrait.jpg?namespace=gamesdb',
                'art_background': 'https://example.invalid/background.webp?namespace=gamesdb'}
        for url in game.values():
            cached = self.heroic / 'images-cache' / hashlib.sha256(url.encode()).hexdigest()
            cached.parent.mkdir(parents=True, exist_ok=True)
            cached.write_bytes(url.encode())
        art = launcher.gog_art(game, '123')
        self.assertEqual(Path(art['poster']).read_bytes(), game['art_square'].encode())
        self.assertEqual(Path(art['thumb']).read_bytes(), game['art_cover'].encode())
        self.assertEqual(Path(art['fanart']).suffix, '.webp')
        self.assertEqual(launcher.gog_art(game, '123'), art)

    def test_artwork_cache_failure_falls_back_to_original(self):
        url = 'https://example.invalid/cover.jpg'
        cached = self.heroic / 'images-cache' / hashlib.sha256(url.encode()).hexdigest()
        cached.parent.mkdir(parents=True)
        cached.write_bytes(b'image')
        with mock.patch.object(Path, 'mkdir', side_effect=OSError('read only')):
            self.assertEqual(launcher.cached_game_image(url), str(cached))


    def test_steam_and_gog_ids_do_not_collide(self):
        gog = {'gog:123': {'title': 'GOG game'}}
        with mock.patch.object(launcher, 'installed_games', return_value={'123': 'Steam game'}), \
                mock.patch.object(launcher, 'owned_gog_games', return_value=gog), \
                mock.patch.object(launcher, 'installed_gog_games', return_value={}), \
                mock.patch.object(launcher, 'local_art', return_value={}):
            games = launcher.game_catalog()
        self.assertEqual(set(games), {'123', 'gog:123'})


class AudioReadinessTests(unittest.TestCase):
    def test_kodi_does_not_claim_cec_adapter(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'peripherals.xml'
            path.write_text('<peripherals><peripheral bus="cec"><setting key="enabled" value="1"/>'
                            '<setting key="other" value="keep"/></peripheral></peripherals>')
            peripheral_patch.patch(path)
            tree = ET.parse(path)
            self.assertEqual(tree.find('./peripheral/setting[@key="enabled"]').get('value'), '0')
            self.assertEqual(tree.find('./peripheral/setting[@key="other"]').get('value'), 'keep')

    def test_changed_cec_schema_is_not_silently_ignored(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'peripherals.xml'
            path.write_text('<peripherals/>')
            with self.assertRaises(RuntimeError):
                peripheral_patch.patch(path)

    def test_ready_server(self):
        with mock.patch.object(audio_ready.subprocess, 'run', return_value=types.SimpleNamespace(returncode=0)) as run:
            self.assertTrue(audio_ready.wait_for_audio('/test/pw-cli', seconds=1))
        self.assertEqual(run.call_args.args[0], ['/test/pw-cli', 'info', '0'])

    def test_unavailable_server_is_bounded(self):
        with mock.patch.object(audio_ready.subprocess, 'run', return_value=types.SimpleNamespace(returncode=1)):
            started = time.monotonic()
            self.assertFalse(audio_ready.wait_for_audio('/test/pw-cli', seconds=0.03))
            self.assertLess(time.monotonic() - started, 0.5)

    def test_hung_probe_is_bounded(self):
        with mock.patch.object(audio_ready.subprocess, 'run', side_effect=subprocess.TimeoutExpired('pw-cli', 0.01)):
            self.assertFalse(audio_ready.wait_for_audio('/test/pw-cli', seconds=0.03))

    def test_missing_probe_fails_closed(self):
        with mock.patch.object(audio_ready.subprocess, 'run', side_effect=FileNotFoundError()):
            self.assertFalse(audio_ready.wait_for_audio('/missing/pw-cli'))


class DeploymentTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.data = self.base / 'profile'
        self.config = {
            'managedAddons': ['skin.theatre', 'plugin.program.localhome'],
            'gui': {'lookandfeel.skin': 'skin.theatre', 'input.enablejoystick': True},
            'mediaSources': [{'path': str(self.base / 'media/films') + '/', 'content': 'movies'}],
            'profileFiles': {'userdata/keymaps/local-home-gamepad.xml': str(ROOT / 'config/kodi/gamepad.xml')},
            'retiredProfilePaths': ['addons/skin.arctic.zephyr.mod',
                                    'userdata/addon_data/script.skinshortcuts', '.nix-menu-signature'],
        }

    def test_first_start_and_idempotence(self):
        prepare_module.prepare(self.config, self.data)
        self.assertIsNotNone(ET.parse(self.data / 'userdata/guisettings.xml').find('resolutions'))
        self.assertIsNotNone(ET.parse(self.data / 'userdata/guisettings.xml').find('viewstates'))
        self.assertFalse((self.data / 'addons/skin.theatre').exists())
        before = sorted(str(p) for p in self.data.rglob('*'))
        prepare_module.prepare(self.config, self.data)
        self.assertEqual(before, sorted(str(p) for p in self.data.rglob('*')))
        self.assertTrue(Path(self.config['mediaSources'][0]['path']).is_dir())

    def test_retires_generated_skin_and_menu_with_backup(self):
        for addon in ('skin.theatre', 'skin.arctic.zephyr.mod'):
            path = self.data / 'addons' / addon
            path.mkdir(parents=True)
            (path / 'sentinel').write_text(addon)
        shortcuts = self.data / 'userdata/addon_data/script.skinshortcuts'
        shortcuts.mkdir(parents=True)
        (shortcuts / 'generated.xml').write_text('old generated menu')
        (self.data / '.nix-menu-signature').write_text('old signature')
        prepare_module.prepare(self.config, self.data)
        self.assertFalse((self.data / 'addons/skin.theatre').exists())
        self.assertFalse((self.data / 'addons/skin.arctic.zephyr.mod').exists())
        self.assertFalse(shortcuts.exists())
        self.assertEqual(len(list((self.data / 'nix-backups').rglob('sentinel'))), 2)
        self.assertEqual(next((self.data / 'nix-backups').rglob('generated.xml')).read_text(), 'old generated menu')
        self.assertFalse((self.data / '.nix-menu-signature').exists())
        self.assertEqual((self.data / 'userdata/keymaps/local-home-gamepad.xml').read_bytes(),
                         (ROOT / 'config/kodi/gamepad.xml').read_bytes())
        self.assertFalse((self.data / 'userdata/addon_data/skin.theatre/settings.xml').exists())
        before = sorted(str(p) for p in self.data.rglob('*'))
        prepare_module.prepare(self.config, self.data)
        self.assertEqual(before, sorted(str(p) for p in self.data.rglob('*')))

    def test_upgrade_snapshots_profile_once_before_changes(self):
        userdata = self.data / 'userdata'
        (userdata / 'Database').mkdir(parents=True)
        (userdata / 'Database/MyVideos131.db').write_bytes(b'old database')
        original = '<settings version="2"><setting id="lookandfeel.skin">old</setting></settings>'
        (userdata / 'guisettings.xml').write_text(original)
        self.config['coreVersion'] = '22.0rc1'
        prepare_module.prepare(self.config, self.data)
        snapshots = list((self.data / 'nix-backups').glob('*/pre-upgrade-userdata'))
        self.assertEqual(len(snapshots), 1)
        self.assertEqual((snapshots[0] / 'guisettings.xml').read_text(), original)
        self.assertEqual((snapshots[0] / 'Database/MyVideos131.db').read_bytes(), b'old database')
        self.assertEqual(snapshots[0].parent.stat().st_mode & 0o777, 0o700)
        prepare_module.prepare(self.config, self.data)
        self.assertEqual(len(list((self.data / 'nix-backups').glob('*/pre-upgrade-userdata'))), 1)
        self.config['coreVersion'] = '22.0rc2'
        prepare_module.prepare(self.config, self.data)
        self.assertEqual(len(list((self.data / 'nix-backups').glob('*/pre-upgrade-userdata'))), 2)

    def test_failed_upgrade_backup_does_not_mark_migration_ready(self):
        (self.data / 'userdata').mkdir(parents=True)
        self.config['coreVersion'] = '22.0rc1'
        with mock.patch.object(prepare_module.shutil, 'copytree', side_effect=OSError('disk full')):
            with self.assertRaises(OSError):
                prepare_module.prepare(self.config, self.data)
        self.assertFalse((self.data / '.nix-core-version').exists())

    def test_preserves_state_and_unowned_preferences(self):
        userdata = self.data / 'userdata'
        (userdata / 'Database').mkdir(parents=True)
        database = userdata / 'Database/MyVideos131.db'
        database.write_bytes(b'watch history sentinel')
        (userdata / 'guisettings.xml').write_text(
            '<settings version="2"><setting id="custom.setting">keep</setting>'
            '<setting id="input.enablejoystick" default="true">false</setting>'
            '<viewstates><videos>keep</videos></viewstates></settings>', encoding='utf-8')
        prepare_module.prepare(self.config, self.data)
        tree = ET.parse(userdata / 'guisettings.xml')
        settings = {e.get('id'): e.text for e in tree.findall('setting')}
        self.assertEqual(settings['custom.setting'], 'keep')
        self.assertEqual(settings['input.enablejoystick'], 'true')
        self.assertEqual(tree.find('viewstates/videos').text, 'keep')
        self.assertEqual(database.read_bytes(), b'watch history sentinel')
        self.assertTrue(list((self.data / 'nix-backups').rglob('guisettings.xml')))

    def test_migrates_only_owned_addons_with_backup(self):
        for addon in ['plugin.program.localhome', 'unrelated.addon']:
            directory = self.data / 'addons' / addon
            directory.mkdir(parents=True)
            (directory / 'sentinel').write_text(addon, encoding='utf-8')
        prepare_module.prepare(self.config, self.data)
        self.assertFalse((self.data / 'addons/plugin.program.localhome').exists())
        self.assertTrue((self.data / 'addons/unrelated.addon/sentinel').exists())
        backups = list((self.data / 'nix-backups').rglob('sentinel'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(encoding='utf-8'), 'plugin.program.localhome')


class LibraryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.database = Path(self.temporary.name) / 'MyVideos131.db'
        with sqlite3.connect(self.database) as connection:
            connection.execute('CREATE TABLE path (idPath INTEGER PRIMARY KEY, strPath TEXT,'
                               'strContent TEXT,strScraper TEXT,scanRecursive INTEGER,'
                               'useFolderNames INTEGER,strSettings TEXT,noUpdate INTEGER,'
                               'exclude INTEGER,allAudio INTEGER)')
            connection.execute('CREATE TABLE episode (idEpisode INTEGER, playCount INTEGER)')
            connection.execute('INSERT INTO episode VALUES (1,7)')
        self.sources = [{'path': '/test/films/', 'content': 'movies'},
                        {'path': '/test/shows/', 'content': 'tvshows'}]

    def test_fresh_database_and_idempotence(self):
        service.configure_sources(self.database, self.sources)
        service.configure_sources(self.database, self.sources)
        with sqlite3.connect(self.database) as connection:
            rows = connection.execute('SELECT strPath,strContent,strScraper FROM path ORDER BY idPath').fetchall()
            self.assertEqual(rows, [('/test/films/', 'movies', 'metadata.local'),
                                    ('/test/shows/', 'tvshows', 'metadata.local')])
            self.assertEqual(connection.execute('SELECT * FROM episode').fetchall(), [(1, 7)])

    def test_restores_declared_content_without_touching_other_sources(self):
        with sqlite3.connect(self.database) as connection:
            connection.execute('INSERT INTO path VALUES (5,?,?,?,?,?,?,?,?,?)',
                               ('/test/films/', 'movies', 'online.scraper', 1, 1, 'old', 1, 1, 0))
            connection.execute('INSERT INTO path VALUES (6,?,?,?,?,?,?,?,?,?)',
                               ('/unrelated/', 'movies', 'other.scraper', 1, 1, 'other', 1, 1, 0))
        service.configure_sources(self.database, self.sources)
        with sqlite3.connect(self.database) as connection:
            row = connection.execute('SELECT * FROM path WHERE idPath=5').fetchone()
            self.assertEqual(row, (5, '/test/films/', 'movies', 'metadata.local', 0, 0, '', 0, 0, 0))
            self.assertEqual(connection.execute('SELECT strScraper FROM path WHERE idPath=6').fetchone(), ('other.scraper',))

    def test_unsupported_schema_is_not_modified(self):
        with sqlite3.connect(self.database) as connection:
            connection.execute('ALTER TABLE path RENAME TO unknown_path')
        with self.assertRaises(RuntimeError):
            service.configure_sources(self.database, self.sources)
        with sqlite3.connect(self.database) as connection:
            self.assertEqual(connection.execute('SELECT COUNT(*) FROM unknown_path').fetchone()[0], 0)


class ContinueTests(unittest.TestCase):
    def test_combined_library_uses_native_ids_and_alphabetical_order(self):
        responses = [json.dumps({'result': {'movies': [
            {'title': 'Z Film', 'movieid': 7, 'file': '/local/film.mkv'},
            {'title': 'Remote', 'movieid': 8, 'file': 'https://example.com/film'}]}}),
            json.dumps({'result': {'tvshows': [{'title': 'A Show', 'tvshowid': 3}]}})]
        with mock.patch.object(launcher.xbmc, 'executeJSONRPC', side_effect=responses, create=True):
            entries = launcher.library_entries()
        self.assertEqual([kind for kind, _ in entries], ['tvshow', 'movie'])
        self.assertEqual(entries[0][1]['tvshowid'], 3)
        self.assertEqual(entries[1][1]['movieid'], 7)

    def episode(self, number=1, season=1, **extra):
        return dict({'episodeid': number + season * 100, 'tvshowid': 1,
                     'season': season, 'episode': number, 'title': 'Episode',
                     'showtitle': 'Show', 'file': '/local/episode.mkv',
                     'playcount': 0}, **extra)

    def test_one_card_per_show_resumes_current_episode(self):
        current = self.episode(lastplayed='2026-10-10 12:00:00', resume={'position': 30})
        entries = continue_watching.select_items([], [current, self.episode(2)], {}, {})
        self.assertEqual([e['media'] for e in entries], [current])

    def test_next_episode_crosses_seasons_and_ignores_specials(self):
        watched = self.episode(12, lastplayed='2026-10-10 12:00:00', playcount=1)
        next_episode = self.episode(1, season=2)
        entries = continue_watching.select_items([], [watched, self.episode(15, season=0), next_episode], {}, {})
        self.assertEqual(entries[0]['media'], next_episode)

    def test_finished_show_and_unstarted_show_are_absent(self):
        watched = self.episode(lastplayed='2026-10-10 12:00:00', playcount=1)
        self.assertEqual(continue_watching.select_items([], [watched], {}, {}), [])
        self.assertEqual(continue_watching.select_items([], [self.episode()], {}, {}), [])

    def test_completed_movies_and_remote_media_are_absent(self):
        movies = [{'title': 'Completed', 'file': '/movie.mkv', 'lastplayed': '2026-10-10 12:00:00'},
                  {'title': 'Remote', 'file': 'https://example.com/movie', 'lastplayed': '2026-10-10 12:00:00', 'resume': {'position': 20}}]
        self.assertEqual(continue_watching.select_items(movies, [], {}, {}), [])

    def test_unified_recency_and_only_installed_games(self):
        movie = {'title': 'Film', 'file': '/movie.mkv', 'lastplayed': '2026-10-10 12:00:00', 'resume': {'position': 20}}
        games = {'new': {'title': 'New game'}, 'removed': {'title': 'Removed', 'installed': False}}
        history = {'new': continue_watching.timestamp(movie['lastplayed']) + 1, 'removed': 9999999999, 'unknown': 9999999999}
        entries = continue_watching.select_items([movie], [], games, history)
        self.assertEqual([e['kind'] for e in entries], ['game', 'movie'])

    def test_game_history_updates_without_duplicate_cards(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / 'activity.sqlite'
            self.assertEqual(continue_watching.game_history(path), {})
            continue_watching.record_game('gog:1', path, 123)
            continue_watching.record_game('gog:1', path, 456)
            self.assertEqual(continue_watching.game_history(path), {'gog:1': 456})


class NavigationTests(unittest.TestCase):
    def test_delayed_home_restore_does_not_close_a_detail_screen(self):
        self.xbmc.getCondVisibility.return_value = False
        self.xbmc.getCondVisibility.side_effect = None
        navigation.switch_page(self.xbmc, self.gui, 'restore')
        self.xbmc.executebuiltin.assert_not_called()
        self.window.setProperty.assert_not_called()

    def test_home_restore_does_not_overwrite_pending_bumper_navigation(self):
        self.properties['LocalHome.PageRequest'] = 'games'
        navigation.switch_page(self.xbmc, self.gui, 'restore')
        self.assertEqual(self.properties['LocalHome.PageRequest'], 'games')
        self.xbmc.executebuiltin.assert_not_called()

    def setUp(self):
        self.properties = {'LocalHome.Page': 'home', 'LocalHome.VideosReady': 'false'}
        self.window = mock.Mock()
        self.window.getProperty.side_effect = lambda key: self.properties.get(key, '')
        self.window.setProperty.side_effect = self.properties.__setitem__
        self.window.clearProperty.side_effect = lambda key: self.properties.pop(key, None)
        self.gui = mock.Mock()
        self.gui.Window.return_value = self.window
        self.xbmc = mock.Mock()
        self.updating = True
        self.xbmc.getCondVisibility.side_effect = lambda condition: (
            self.updating if condition.endswith('.IsUpdating') else True)
        self.monitor = self.xbmc.Monitor.return_value
        self.monitor.abortRequested.return_value = False

    def test_slow_destination_keeps_current_page_until_listing_is_ready(self):
        def finish(_):
            self.assertEqual(self.properties['LocalHome.Page'], 'home')
            self.xbmc.executebuiltin.assert_not_called()
            self.assertNotIn('LocalHome.PageMotion', self.properties)
            self.properties['LocalHome.VideosReady'] = 'true'
            self.updating = False
            return False
        self.monitor.waitForAbort.side_effect = finish
        navigation.switch_page(self.xbmc, self.gui, 'next')
        self.assertEqual(self.properties['LocalHome.Page'], 'videos')
        self.assertEqual(self.properties['LocalHome.PageMotion'], 'videos.next')
        self.xbmc.executebuiltin.assert_called_once_with('SetFocus(30121)')
        self.assertNotIn('LocalHome.PageRequest', self.properties)

    def test_newer_request_prevents_stale_page_from_being_committed(self):
        def supersede(_):
            self.properties['LocalHome.PageRequest'] = 'games'
            return False
        self.monitor.waitForAbort.side_effect = supersede
        navigation.switch_page(self.xbmc, self.gui, 'next')
        self.assertEqual(self.properties['LocalHome.Page'], 'home')
        self.assertEqual(self.properties['LocalHome.PageRequest'], 'games')
        self.xbmc.executebuiltin.assert_not_called()

    def test_completed_empty_page_keeps_focus_outside_navigation(self):
        self.properties['LocalHome.GamesReady'] = 'true'
        self.xbmc.getCondVisibility.side_effect = lambda condition: condition == 'Window.IsActive(Home)'
        navigation.switch_page(self.xbmc, self.gui, 'games')
        self.assertEqual(self.properties['LocalHome.Page'], 'games')
        self.xbmc.executebuiltin.assert_called_once_with('SetFocus(30110)')

    def test_aborted_load_does_not_replace_the_current_page(self):
        self.monitor.waitForAbort.return_value = True
        navigation.switch_page(self.xbmc, self.gui, 'next')
        self.assertEqual(self.properties['LocalHome.Page'], 'home')
        self.xbmc.executebuiltin.assert_not_called()


class DeclarationTests(unittest.TestCase):

    def test_openbox_hides_library_not_games_or_dialogs(self):
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary) / 'source.xml'
            output = Path(temporary) / 'output.xml'
            source.write_text('<openbox_config xmlns="http://openbox.org/3.4/rc">'
                              '<focus><focusNew>yes</focusNew></focus><applications/></openbox_config>')
            openbox_patch.configure_openbox(source, output)
            ns = {'o': 'http://openbox.org/3.4/rc'}
            tree = ET.parse(output)
            self.assertEqual(tree.find('o:focus/o:focusNew', ns).text, 'yes')
            rules = tree.findall('o:applications/o:application', ns)
            self.assertEqual(len(rules), 2)
            for rule in rules:
                self.assertEqual(rule.get('title'), 'Steam')
                self.assertEqual(rule.get('type'), 'normal')
                self.assertIn(rule.get('class'), ('Steam', 'steam'))
                self.assertEqual(rule.find('o:iconic', ns).text, 'yes')
                self.assertEqual(rule.find('o:focus', ns).text, 'no')

    def test_gamepad_window_shortcuts_and_page_navigation(self):
        keymap = ET.parse(ROOT / 'config/kodi/gamepad.xml')
        self.assertEqual([n.tag for n in keymap.getroot()], ['global', 'window1100', 'Home', 'FullscreenVideo', 'VideoOSD', 'Videos', 'Programs'])
        self.assertEqual(keymap.find('global/keyboard/f6').text, 'ActivateWindow(Settings)')
        self.assertEqual(keymap.find('global/keyboard/f7').text, 'ActivateWindow(ShutdownMenu)')
        self.assertEqual(keymap.find('global/joystick/guide').text, 'ActivateWindow(ShutdownMenu)')
        self.assertEqual(keymap.find('global/joystick/back').text, 'Noop')
        joystick = keymap.find('Home/joystick')
        self.assertEqual(joystick.find('start').text, 'ActivateWindow(Settings)')
        self.assertEqual(joystick.find('b').text, 'RunScript(plugin.program.localhome,page,back)')
        self.assertEqual(joystick.find("b[@holdtime='500']").text, 'ActivateWindow(ShutdownMenu)')
        for window in ('Home', 'Videos', 'Programs'):
            for key, button in (('pageup', 'leftbumper'), ('pagedown', 'rightbumper')):
                action = keymap.find(window + '/keyboard/' + key).text
                self.assertEqual(keymap.find(window + '/joystick/' + button).text, action)
                self.assertIn('RunScript(plugin.program.localhome,page,', action)
                self.assertNotIn('PageUp', action)
        self.assertEqual(keymap.find("Home/keyboard/backspace[@mod='longpress']").text,
                         'ActivateWindow(ShutdownMenu)')
        back = 'RunScript(plugin.program.localhome,back)'
        self.assertEqual(keymap.find('FullscreenVideo/keyboard/backspace').text, back)
        self.assertEqual(keymap.find('FullscreenVideo/keyboard/escape').text, back)
        self.assertEqual(keymap.find('FullscreenVideo/joystick/b').text, back)
        self.assertEqual(keymap.find('VideoOSD/keyboard/backspace').text, 'Close')
        self.assertEqual(keymap.find('FullscreenVideo/keyboard/right').text, 'StepForward')
        self.assertEqual(keymap.find('FullscreenVideo/keyboard/return').text, 'PlayPause')
        self.assertEqual(keymap.find('FullscreenVideo/joystick/a').text, 'PlayPause')
        self.assertEqual(keymap.find('VideoOSD/keyboard/right').text, 'StepForward')
        self.assertEqual(keymap.find('global/joystick/x').text, 'ContextMenu')
        self.assertEqual(keymap.find('FullscreenVideo/joystick/x').text, 'OSD')
        self.assertEqual(keymap.find('VideoOSD/joystick/x').text, 'Close')
        for window in ('global', 'FullscreenVideo', 'VideoOSD'):
            self.assertEqual(keymap.find(window + '/joystick/y').text, 'PlayPause')


class SessionOwnershipTests(unittest.TestCase):
    @unittest.skipUnless(os.environ.get('KODI_LAUNCH_INTEGRATION'), 'opt-in real user service test')
    def test_session_owner_term_and_kill_reap_descendants(self):
        code = ('import os,time,json\nchild=os.fork()\n'
                'if child == 0: time.sleep(300)\n'
                'else:\n print(json.dumps([os.getpid(),child]),flush=True)\n time.sleep(300)\n')
        for death in (signal.SIGTERM, signal.SIGKILL):
            process = subprocess.Popen([sys.executable, str(ROOT / 'pkgs/kodi/session_owner.py'),
                'systemd-run', 'systemctl', str(ROOT / 'pkgs/kodi/session_guardian.py'),
                sys.executable, '-u', '-c', code],
                env={**os.environ, 'KODI_DATA': '/tmp/kodi-ownership-test'},
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, start_new_session=True)
            try:
                self.assertTrue(select.select([process.stdout], [], [], 10)[0], 'owned child did not start')
                children = json.loads(process.stdout.readline())
                process.send_signal(death)
                process.wait(timeout=10)
                deadline = time.monotonic() + 8
                while True:
                    live = [pid for pid in children if Path('/proc', str(pid), 'stat').exists()
                            and Path('/proc', str(pid), 'stat').read_text().split()[2] != 'Z']
                    if not live:
                        break
                    self.assertLess(time.monotonic(), deadline, 'session death orphaned descendants')
                    time.sleep(0.1)
            finally:
                if process.poll() is None:
                    process.kill()
                    process.wait(timeout=5)
                process.stdout.close()
                process.stderr.close()


class VideoControlTests(unittest.TestCase):
    def test_compact_native_osd(self):
        root = ET.parse(ROOT / 'config/kodi/skin.theatre/1080i/VideoOSD.xml').getroot()
        buttons = root.findall('.//control[@type="button"]')
        self.assertEqual(len(buttons), 3)
        self.assertEqual(root.findtext('defaultcontrol'), '13')
        ids = {b.get('id') for b in buttons}
        self.assertTrue(all(b.findtext('onup') in ids and b.findtext('ondown') in ids for b in buttons))
        self.assertTrue(all(b.findtext('onleft') == 'StepBack' and b.findtext('onright') == 'StepForward' for b in buttons))
        self.assertFalse(any('Seek(' in b.findtext('onclick') for b in buttons))
        self.assertEqual(root.findtext('.//control[@type="progress"]/info'), 'Player.Progress')
        self.assertFalse(ET.parse(ROOT / 'config/kodi/skin.theatre/1080i/PlayerControls.xml').getroot().findall('.//control[@type="button"]'))

    def test_episode_exit_opens_native_show_after_stopping(self):
        xbmc = mock.Mock()
        player = xbmc.Player.return_value
        player.isPlayingVideo.side_effect = [True, False]
        player.getVideoInfoTag.return_value.getMediaType.return_value = 'episode'
        player.getVideoInfoTag.return_value.getDbId.return_value = 9
        xbmc.executeJSONRPC.return_value = json.dumps({'result': {'episodedetails': {'tvshowid': 4}}})
        xbmc.getCondVisibility.side_effect = [False, True, False, False, False]
        xbmc.Monitor.return_value.waitForAbort.return_value = False
        video_controls.leave_player(xbmc)
        player.stop.assert_called_once()
        xbmc.executebuiltin.assert_called_with('ActivateWindow(Videos,videodb://tvshows/titles/4/,return)')
        self.assertEqual(xbmc.getCondVisibility.call_count, 5)

    def test_prepared_episode_parent_returns_without_home_or_queries(self):
        xbmc = mock.Mock()
        xbmc.getCondVisibility.return_value = True
        video_controls.leave_player(xbmc)
        xbmc.Player.return_value.stop.assert_called_once()
        xbmc.executeJSONRPC.assert_not_called()
        xbmc.Monitor.assert_not_called()
        xbmc.executebuiltin.assert_called_once_with('Dialog.Close(VideoOSD,true)')

    def test_continue_opens_episode_list_and_selects_id_without_playing(self):
        xbmc = mock.Mock()
        gui = mock.Mock()
        xbmc.executeJSONRPC.return_value = json.dumps({'result': {
            'episodedetails': {'tvshowid': 4, 'file': '/local/episode.mkv'}}})
        xbmc.getCondVisibility.return_value = True
        labels = {'Container(50).NumItems': '2',
                  'Container(50).ListItemAbsolute(0).DBTYPE': '',
                  'Container(50).ListItemAbsolute(1).DBTYPE': 'episode',
                  'Container(50).ListItemAbsolute(1).DBID': '42',
                  'Container(50).ListItemAbsolute(2).DBTYPE': 'episode',
                  'Container(50).ListItemAbsolute(2).DBID': '9'}
        xbmc.getInfoLabel.side_effect = lambda label: labels.get(label, '')
        video_controls.open_episode(xbmc, gui, '9')
        xbmc.executebuiltin.assert_called_once_with(
            'ActivateWindow(Videos,videodb://tvshows/titles/4/,return)', True)
        gui.Window.assert_called_once_with(10025)
        gui.Window.return_value.getControl.return_value.selectItem.assert_called_once_with(2)
        gui.Window.return_value.setFocusId.assert_called_once_with(50)
        self.assertEqual(xbmc.executeJSONRPC.call_count, 1)
        self.assertEqual(json.loads(xbmc.executeJSONRPC.call_args.args[0])['method'],
                         'VideoLibrary.GetEpisodeDetails')

    def test_invalid_or_nonlocal_episode_never_launches(self):
        xbmc = mock.Mock()
        xbmc.executeJSONRPC.return_value = json.dumps({'result': {
            'episodedetails': {'tvshowid': 4, 'file': 'https://example.invalid/video'}}})
        video_controls.open_episode(xbmc, mock.Mock(), 9)
        xbmc.executebuiltin.assert_not_called()
        self.assertEqual(xbmc.executeJSONRPC.call_count, 1)

    def test_movie_exit_does_not_invent_episode_navigation(self):
        xbmc = mock.Mock()
        player = xbmc.Player.return_value
        player.isPlayingVideo.side_effect = [True, False]
        player.getVideoInfoTag.return_value.getMediaType.return_value = 'movie'
        video_controls.leave_player(xbmc)
        player.stop.assert_called_once()
        xbmc.executeJSONRPC.assert_not_called()
        self.assertEqual(xbmc.executebuiltin.call_count, 1)

    def test_failed_stop_never_navigates_over_playback(self):
        xbmc = mock.Mock()
        xbmc.Player.return_value.getVideoInfoTag.return_value.getMediaType.return_value = 'movie'
        xbmc.Monitor.return_value.waitForAbort.return_value = False
        video_controls.leave_player(xbmc)
        self.assertEqual(xbmc.executebuiltin.call_count, 1)


class InputRoutingTests(unittest.TestCase):
    def test_gamescope_launch_waits_for_native_surface_and_owns_process(self):
        for transient in (False, True):
            home, progress, monitor, launch = (mock.Mock() for _ in range(4))
            home.getProperty.return_value = ''
            progress.iscanceled.return_value = False
            monitor.abortRequested.return_value = False
            monitor.waitForAbort.return_value = False
            launch.poll.side_effect = [None, None, None, 0] if transient else [None, None, 0]
            with mock.patch.dict(os.environ, {'THEATRE_COMPOSITOR': 'gamescope'}), \
                    mock.patch.dict(game_session.TOOLS, {'xprop': '/trusted/xprop'}), \
                    mock.patch.object(game_session.xbmcgui, 'Window', return_value=home, create=True), \
                    mock.patch.object(game_session.xbmcgui, 'DialogProgress', return_value=progress, create=True), \
                    mock.patch.object(game_session.xbmc, 'Monitor', return_value=monitor, create=True), \
                    mock.patch.object(game_session, 'available_windows', return_value={}), \
                    mock.patch.object(gamescope, 'focused', side_effect=[OSError('temporary query failure'), gamescope.GAME_APP] if transient else None, return_value=gamescope.GAME_APP), \
                    mock.patch.object(gamescope, 'focus') as focus, \
                    mock.patch.object(input_router, 'save_state') as state, \
                    mock.patch.object(continue_watching, 'record_game') as record, \
                    mock.patch.object(continue_watching, 'refresh'):
                self.assertTrue(game_session.run_game('custom:hollie', {'title': 'Hollie'}, lambda: launch))
                record.assert_called_once_with('custom:hollie')
                launch.stop.assert_called_once()
                home.clearProperty.assert_called_once_with('LocalHome.GamePending')
                state.assert_called_with({'kodi': gamescope.KODI_APP, 'game': None})
                self.assertEqual(focus.call_args_list, [mock.call('/trusted/xprop', gamescope.GAME_APP), mock.call('/trusted/xprop', gamescope.KODI_APP)])

    def test_gamescope_native_game_focus_routes_controller(self):
        router = input_router.Router()
        with mock.patch.dict(os.environ, {'THEATRE_COMPOSITOR': 'gamescope'}), \
                mock.patch.dict(game_session.TOOLS, {'xprop': '/trusted/xprop'}), \
                mock.patch.object(gamescope, 'focused', side_effect=[gamescope.GAME_APP, gamescope.KODI_APP]), \
                mock.patch.object(router, 'profile', return_value=True) as profile, \
                mock.patch.object(router, 'native_input') as native, \
                mock.patch.object(input_router, 'windows') as windows:
            router.tick({})
            profile.assert_called_with('game')
            router.tick({})
            profile.assert_called_with('kodi')
            native.assert_called_with(False)
            windows.assert_not_called()

    def test_gamescope_focus_keeps_kodi_as_loading_fallback(self):
        with mock.patch.object(gamescope.subprocess, 'run') as run:
            gamescope.focus('/trusted/xprop', gamescope.GAME_APP)
            self.assertEqual(run.call_args.args[0][-1], f'{gamescope.GAME_APP}, {gamescope.KODI_APP}')
            gamescope.focus('/trusted/xprop', gamescope.KODI_APP)
            self.assertEqual(run.call_args.args[0][-1], str(gamescope.KODI_APP))
            with self.assertRaises(ValueError):
                gamescope.focus('/trusted/xprop', 0)

    def test_gamescope_home_works_without_an_x11_kodi_window(self):
        for active, target in [(gamescope.GAME_APP, gamescope.KODI_APP), (gamescope.KODI_APP, gamescope.GAME_APP)]:
            with tempfile.TemporaryDirectory() as temp:
                directory = Path(temp)
                (directory / 'kodi-localhome-game.json').write_text(json.dumps({'kodi': gamescope.KODI_APP, 'game': gamescope.GAME_APP}))
                with mock.patch.dict(os.environ, {'THEATRE_COMPOSITOR': 'gamescope'}), \
                        mock.patch.object(session_home, 'runtime', return_value=directory), \
                        mock.patch.object(gamescope, 'focused', return_value=active), \
                        mock.patch.object(gamescope, 'focus') as focus, \
                        mock.patch.object(session_home, 'kodi_home') as home:
                    session_home.toggle('/trusted/xprop', '/trusted/xdotool')
                    focus.assert_called_once_with('/trusted/xprop', target)
                    self.assertEqual(home.called, target == gamescope.KODI_APP)

    def test_steam_ui_is_not_a_game(self):
        self.assertTrue(input_router.steam_ui({'class': '"steam", "Steam"'}))
        self.assertFalse(input_router.steam_ui({'class': '"steam_app_123", "steam_app_123"'}))
        with mock.patch.object(input_router, 'find_game', return_value='1'):
            self.assertIsNone(input_router.choose_game({'123': {'source': 'Standalone (native)', 'install_path': '/installed/game'}},
                {'1': {'class': '"steam", "Steam"'}}, '1'))

    def test_tracks_background_game_for_home_resume(self):
        patcher = mock.patch.object(Path, 'read_bytes', autospec=True, side_effect=lambda path: b'/installed/game/game' if path.parts[-2] == '2' else b'/unrelated/kodi')
        patcher.start()
        self.addCleanup(patcher.stop)
        catalog = {'123': {'source': 'Standalone (native)', 'install_path': '/installed/game'}}
        current = {'0x1': {'class': '"kodi", "Kodi"', 'normal': True, 'pid': '1'},
                   '0x2': {'class': '"game", "Game"', 'normal': True, 'pid': '2'}}
        self.assertEqual(input_router.choose_game(catalog, current, '0x1', '0x2'), '0x2')
        self.assertEqual(input_router.choose_game(catalog, current, '0x2'), '0x2')

    def test_focus_selects_profile_and_exit_restores_kodi(self):
        router = input_router.Router()
        patcher = mock.patch.object(Path, 'read_bytes', autospec=True, side_effect=lambda path: b'/installed/game/game' if path.parts[-2] == '2' else b'/unrelated/kodi')
        patcher.start()
        self.addCleanup(patcher.stop)
        catalog = {'123': {'source': 'Standalone (native)', 'install_path': '/installed/game'}}
        current = {'0x1': {'class': '"kodi", "Kodi"', 'normal': True, 'pid': '1'},
                   '0x2': {'class': '"game", "Game"', 'normal': True, 'pid': '2'}}
        with mock.patch.object(input_router, 'windows', return_value=current), \
                mock.patch.object(input_router, 'command', return_value='_NET_ACTIVE_WINDOW: 0x2') as command, \
                mock.patch.object(router, 'profile') as profile, \
                mock.patch.object(router, 'native_input') as native, \
                mock.patch.object(input_router, 'save_state'):
            profile.return_value = True
            router.tick(catalog)
            profile.assert_called_with('game')
            native.assert_called_with(False)
            command.return_value = '_NET_ACTIVE_WINDOW: 0x1'
            router.tick(catalog)
            profile.assert_called_with('kodi')
            current.pop('0x2')
            router.tick(catalog)
            command.assert_any_call('xdotool', 'windowactivate', '0x1')

    def test_no_managed_controller_restores_native_navigation(self):
        router = input_router.Router()
        with mock.patch.object(input_router, 'windows', return_value={'0x1': {'class': '"kodi", "Kodi"'}}), \
                mock.patch.object(input_router, 'command', return_value='_NET_ACTIVE_WINDOW: 0x1'), \
                mock.patch.object(router, 'profile', return_value=False), \
                mock.patch.object(router, 'native_input') as native, \
                mock.patch.object(input_router, 'save_state'):
            router.tick({})
            native.assert_called_once_with(True)

    def test_native_input_changes_are_idempotent(self):
        router = input_router.Router()
        with mock.patch.object(input_router.xbmc, 'executeJSONRPC', return_value='{"result":true}', create=True) as rpc:
            router.native_input(False)
            router.native_input(False)
            router.native_input(True)
            self.assertEqual(rpc.call_count, 2)

    def test_daemon_failure_discards_stale_managed_state(self):
        router = input_router.Router()
        router.applied = {'0': 'kodi'}
        with mock.patch.object(input_router, 'command', side_effect=OSError('daemon unavailable')):
            with self.assertRaises(OSError):
                router.profile('kodi')
            self.assertEqual(router.applied, {})

    def test_profile_changes_do_not_recreate_virtual_devices(self):
        router = input_router.Router()
        with mock.patch.object(input_router, 'command', return_value='/org/shadowblip/InputPlumber/CompositeDevice0') as command:
            router.profile('kodi')
            router.profile('kodi')
            router.profile('game')
            loads = [call for call in command.call_args_list if call.args[0] == 'inputplumber']
            self.assertEqual(len(loads), 2)
            self.assertEqual(loads[-1].args, ('inputplumber', 'device', '0', 'profile', 'load', '/etc/inputplumber/profiles.d/game.yaml'))

    def test_openbox_home_is_session_command(self):
        with tempfile.TemporaryDirectory() as temporary:
            source, output = Path(temporary) / 'source.xml', Path(temporary) / 'output.xml'
            source.write_text('<openbox_config><keyboard><keybind key="A-F4" /></keyboard></openbox_config>')
            openbox_patch.configure_openbox(source, output, '/trusted/python /trusted/home.py')
            root = ET.parse(output)
            self.assertIsNotNone(root.find('keyboard/keybind[@key="A-F4"]'))
            self.assertEqual(root.find('keyboard/keybind[@key="F13"]/action/command').text,
                             '/trusted/python /trusted/home.py')

    def test_home_toggle_only_activates_existing_game_or_kodi(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            (directory / 'kodi-localhome-game.json').write_text(json.dumps({'kodi': '0x1', 'game': '0x2'}))
            with mock.patch.object(session_home, 'runtime', return_value=directory), \
                    mock.patch.object(session_home.subprocess, 'check_output', return_value='_NET_CLIENT_LIST: 0x1, 0x2\n_NET_ACTIVE_WINDOW: 0x1'), \
                    mock.patch.object(session_home.subprocess, 'run') as run:
                session_home.toggle('/trusted/xprop', '/trusted/xdotool')
                run.assert_called_once_with(['/trusted/xdotool', 'windowactivate', '0x2'], check=True, timeout=3)


    def test_controller_matches_native_device(self):
        device = ET.parse(ROOT / 'config/kodi/Pro_Controller_14b_6a.xml').find('device')
        self.assertEqual(device.get('buttoncount'), '14')
        self.assertEqual(device.get('axiscount'), '6')
        features = {f.get('name'): f for f in device.find('controller')}
        self.assertEqual(features['a'].get('button'), '1')
        self.assertEqual(features['b'].get('button'), '0')
        for feature in features.values():
            if feature.get('button'):
                self.assertLess(int(feature.get('button')), 14)


if __name__ == '__main__':
    unittest.main(verbosity=2)
