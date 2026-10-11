import importlib.util
import json
from pathlib import Path
import tempfile
import sys
import unittest
from unittest import mock

spec = importlib.util.spec_from_file_location('gog_cli', Path(__file__).with_name('gog.py'))
gog = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gog)


class ImportTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / 'bin').mkdir()
        (self.root / 'bin/game.exe').touch()
        (self.root / 'launcher.exe').touch()
        (self.root / 'goggame-123.info').write_text(json.dumps({
            'gameId': '123', 'rootGameId': '123', 'name': 'Test game',
            'playTasks': [{'isPrimary': True, 'path': 'launcher.exe'},
                          {'path': 'bin/game.exe', 'arguments': '--foo "two words"'}]}))

    def test_primary_task_and_default_prefix(self):
        item = gog.register(self.root)
        self.assertEqual(item['appName'], '123')
        self.assertEqual(item['executable'], str(self.root / 'launcher.exe'))
        self.assertTrue(item['prefix'].endswith('/gog-123'))

    def test_nested_installation_keeps_download_and_launch_roots_distinct(self):
        wrapper = self.root / 'download'
        actual = wrapper / 'A Short Hike'
        actual.mkdir(parents=True)
        (actual / 'game.exe').touch()
        (actual / 'goggame-456.info').write_text(json.dumps({
            'gameId': '456', 'name': 'Nested game',
            'playTasks': [{'isPrimary': True, 'path': 'game.exe'}]}))
        result = gog.register(wrapper, '456')
        self.assertEqual(result['download_path'], str(wrapper))
        self.assertEqual(result['install_path'], str(actual))
        self.assertEqual(result['working_dir'], str(actual))
        self.assertEqual(result['executable'], str(actual / 'game.exe'))
        updated = gog.register(wrapper, '456', result, {'targetExe': result['executable'], 'winePrefix': result['prefix']})
        self.assertEqual(updated, result)

    def test_nested_metadata_rejects_ambiguity_and_symlink_escape(self):
        wrapper = self.root / 'download'
        for name in ('one', 'two'):
            folder = wrapper / name
            folder.mkdir(parents=True)
            (folder / 'goggame-456.info').write_text(json.dumps({'gameId': '456', 'playTasks': [{'path': 'game.exe'}]}))
        with self.assertRaisesRegex(ValueError, 'Multiple'):
            gog.register(wrapper, '456')
        outside = self.root / 'external.info'
        outside.write_text('{}')
        (wrapper / 'goggame-789.info').symlink_to(outside)
        with self.assertRaisesRegex(ValueError, 'escapes'):
            gog.register(wrapper, '789')

    def test_preserves_custom_executable_prefix_and_arguments(self):
        item = gog.register(self.root, settings={'targetExe': str(self.root / 'bin/game.exe'), 'winePrefix': '/existing/prefix'})
        self.assertEqual(item['executable'], str(self.root / 'bin/game.exe'))
        self.assertEqual(item['working_dir'], str(self.root / 'bin'))
        self.assertEqual(item['prefix'], '/existing/prefix')
        self.assertEqual(item['arguments'], ['--foo', 'two words'])

    def test_old_heroic_alternative_executable(self):
        item = gog.register(self.root, settings={'lastUsedLaunchOption': {'type': 'altExe', 'executable': str(self.root / 'bin/game.exe')}})
        self.assertEqual(item['executable'], str(self.root / 'bin/game.exe'))

    def test_update_and_repair_preserve_saved_launch_settings(self):
        state = self.root / 'state'
        working = self.root / 'assets'
        working.mkdir()
        native = self.root / 'bin/native.sh'
        native.touch()
        for platform in ('windows', 'linux'):
            for command in ('update', 'repair'):
                for custom in (True, False):
                    with self.subTest(platform=platform, command=command, custom=custom):
                        record = gog.register(self.root, settings={
                            'targetExe': str(self.root / 'bin/game.exe'),
                            'winePrefix': '/existing/custom-prefix',
                        })
                        record.update(platform=platform, working_dir=str(working),
                                      arguments=['--custom', 'two words'] if custom else [],
                                      environment={'WINEDLLOVERRIDES': 'winhttp=n,b'} if custom else {})
                        if platform == 'linux':
                            # Registered native games need not launch start.sh.
                            record['executable'] = str(native)
                        gog.save(state / 'installed.json', {'installed': [record]})
                        with mock.patch.object(gog, 'state_dir', return_value=state), \
                                mock.patch.object(gog, 'download_with_progress') as download, \
                                mock.patch.object(sys, 'argv', ['gog', '--gogdl', '/trusted/gogdl', command, '123']), \
                                mock.patch('builtins.print'):
                            gog.main()
                        refreshed = gog.read(state / 'installed.json')['installed'][0]
                        for key in ('executable', 'arguments', 'environment', 'working_dir', 'prefix', 'install_path'):
                            self.assertEqual(refreshed[key], record[key], key)
                        self.assertEqual(download.call_args.args[0][1:3], [command, '123'])

    def test_case_insensitive_metadata(self):
        self.assertEqual(gog.case_path(self.root, 'BIN\\GAME.EXE'), self.root / 'bin/game.exe')

    def test_rejects_escape_paths_and_missing_executables(self):
        with self.assertRaises(ValueError):
            gog.register(self.root, settings={'targetExe': '/outside.exe'})
        with self.assertRaises(ValueError):
            gog.case_path(self.root, '../outside.exe')
        with self.assertRaises(ValueError):
            gog.register(self.root, settings={'targetExe': str(self.root / 'missing.exe')})

    def test_private_atomic_state(self):
        path = self.root / 'state/installed.json'
        gog.save(path, {'installed': []})
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        self.assertEqual(gog.read(path), {'installed': []})
        self.assertEqual(list(path.parent.glob('.gog-*')), [])

    def test_estimates_sum_shared_and_selected_language_not_other_languages(self):
        response = mock.Mock(stdout=json.dumps({'size': {
            '*': {'download_size': 100, 'disk_size': 200},
            'en-US': {'download_size': 30, 'disk_size': 40},
            'de-DE': {'download_size': 500, 'disk_size': 600}}}))
        with mock.patch.object(gog.subprocess, 'run', return_value=response) as run:
            estimate = gog.estimate_install('/trusted/gogdl', '123', self.root / 'not-created/game')
        self.assertEqual(estimate['download_bytes'], 130)
        self.assertEqual(estimate['installed_bytes'], 240)
        self.assertGreater(estimate['free_bytes'], 0)
        self.assertFalse((self.root / 'not-created').exists())
        self.assertIn('info', run.call_args.args[0])

    def test_progress_parser_reports_actual_numbers_and_ignores_secrets(self):
        status = {}
        self.assertTrue(gog.progress_event('[PROGRESS] INFO: = Progress: 47.56 153987015/323791264, Running for: 00:00:06, ETA: 00:00:07', status))
        self.assertTrue(gog.progress_event('[PROGRESS] INFO: = Downloaded: 55.95 MiB, Written: 146.85 MiB', status))
        self.assertTrue(gog.progress_event('[PROGRESS] INFO: + Download\t- 17.07 MiB/s (raw) / 21.41 MiB/s (decompressed)', status))
        self.assertEqual(status['percent'], 47.56)
        self.assertEqual(status['eta_seconds'], 7)
        self.assertEqual(status['written_bytes'], 153987015)
        self.assertEqual(status['downloaded_bytes'], int(55.95 * 1024**2))
        self.assertFalse(gog.progress_event('Error https://example.com/?token=secret', status))
        self.assertNotIn('secret', json.dumps(status))
        gog.progress_event('[PROGRESS] Progress: 0.00 0/100, Running for: 00:00:00, ETA: 00:00:00', status)
        self.assertIsNone(status['eta_seconds'])

    def test_streamed_downloader_progress_is_private_and_keeps_estimates(self):
        path = self.root / 'status.json'
        gog.save(path, {'download_bytes': 123, 'installed_bytes': 200})
        line = '[PROGRESS] INFO: = Progress: 100.00 200/200, Running for: 00:00:01, ETA: 00:00:00'
        gog.download_with_progress([sys.executable, '-c', 'print(' + repr(line) + ')'], path)
        status = gog.read(path)
        self.assertEqual(status['phase'], 'registering')
        self.assertEqual(status['percent'], 100)
        self.assertEqual(status['download_bytes'], 123)
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_zero_exit_with_incomplete_progress_is_not_success(self):
        line = '[PROGRESS] INFO: = Progress: 50.00 100/200, Running for: 00:00:01, ETA: 00:00:01'
        with self.assertRaisesRegex(ValueError, 'before all files'):
            gog.download_with_progress([sys.executable, '-c', 'print(' + repr(line) + ')'])

    def test_artwork_uses_real_portrait_and_caches_bytes(self):
        import io
        metadata = io.BytesIO(json.dumps({'game': {
            'vertical_cover': {'url_format': 'https://images.gog.com/portrait{formatter}.{ext}?namespace=gamesdb'},
            'horizontal_artwork': {'url_format': 'https://images.gog.com/banner{formatter}.{ext}?namespace=gamesdb'}}}).encode())
        product = io.BytesIO(json.dumps({'images': {'background': '//images-1.gog-statics.com/background.jpg'}}).encode())
        portrait, banner, background = mock.MagicMock(), mock.MagicMock(), mock.MagicMock()
        for response in (portrait, banner, background):
            response.__enter__.return_value = response
            response.headers = {'Content-Type': 'image/jpeg'}
            response.read.return_value = b'image fixture'
        with mock.patch.object(gog, 'state_dir', return_value=self.root / 'state'), \
                mock.patch.object(gog, 'urlopen', side_effect=[metadata, product, portrait, banner, background]) as request:
            result = gog.cache_artwork({'id': '123', 'title': 'Test'})
            self.assertIn('/portrait.jpg', result['art_square'])
            self.assertIn('/banner.jpg', result['art_cover'])
            self.assertEqual(result['art_background'], 'https://images-1.gog-statics.com/background.jpg')
            self.assertEqual(gog.cache_artwork(result), result)
            self.assertEqual(request.call_count, 5)
        self.assertEqual(len(list((self.root / 'state/images-cache').iterdir())), 3)

    def test_uninstall_is_recoverable_and_preserves_prefix(self):
        home = self.root / 'home'
        game = home / 'Games/GOG/123'
        game.mkdir(parents=True)
        (game / 'save.dat').write_text('save data')
        prefix = home / 'Games/Prefixes/gog-123'
        prefix.mkdir(parents=True)
        (prefix / 'save.dat').write_text('prefix save')
        state = home / 'state'
        gog.save(state / 'installed.json', {'installed': [{'appName': '123', 'install_path': str(game), 'prefix': str(prefix)}]})
        with mock.patch.object(gog.Path, 'home', return_value=home), mock.patch.object(gog, 'state_dir', return_value=state):
            gog.uninstall('123')
        self.assertFalse(game.exists())
        self.assertEqual(gog.read(state / 'installed.json'), {'installed': []})
        recovery = next((state / 'removed').iterdir())
        self.assertEqual((recovery / 'files/save.dat').read_text(), 'save data')
        self.assertEqual((prefix / 'save.dat').read_text(), 'prefix save')
        self.assertEqual(gog.read(recovery / 'record.json')['install_path'], str(game))

    def test_uninstall_refuses_broad_directory(self):
        state = self.root / 'state'
        gog.save(state / 'installed.json', {'installed': [{'appName': '123', 'install_path': str(self.root)}]})
        with mock.patch.object(gog, 'state_dir', return_value=state), self.assertRaises(ValueError):
            gog.uninstall('123')
        self.assertTrue(self.root.exists())


if __name__ == '__main__':
    unittest.main()
