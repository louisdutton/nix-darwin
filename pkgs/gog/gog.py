"""GOG account inventory and installed-state bridge; credentials stay writable."""
import argparse
import fcntl
import hashlib
from html import unescape
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import uuid
from urllib.request import urlopen
from urllib.parse import urlsplit


def cache_artwork(item):
    """Download GOG's real portrait cover, not a cropped store banner."""
    appid = str(item['id'])
    if not appid.isdecimal():
        raise ValueError('GOG ID must be numeric')
    cache = state_dir() / 'images-cache'
    def cached(key):
        return item.get(key) and (cache / hashlib.sha256(item[key].encode()).hexdigest()).is_file()
    if all(cached(key) for key in ('art_square', 'art_cover', 'art_background')):
        return item
    sources = {}
    if not all(cached(key) for key in ('art_square', 'art_cover')):
        with urlopen('https://gamesdb.gog.com/platforms/gog/external_releases/' + appid, timeout=20) as response:
            game = json.load(response)['game']
        for key, field in [('art_square', 'vertical_cover'), ('art_cover', 'horizontal_artwork')]:
            template = game.get(field, {}).get('url_format')
            if template:
                sources[key] = template.format(formatter='', ext='jpg')
    if not cached('art_background'):
        try:
            with urlopen('https://api.gog.com/products/' + appid, timeout=20) as response:
                background = json.load(response).get('images', {}).get('background')
            if background:
                sources['art_background'] = 'https:' + background if background.startswith('//') else background
        except Exception:
            # GOG's wide artwork is an appropriate fallback, never a portrait.
            sources['art_background'] = sources.get('art_cover') or item.get('art_cover', '')
        if 'art_background' not in sources:
            sources['art_background'] = sources.get('art_cover') or item.get('art_cover', '')
    result = dict(item)
    cache.mkdir(parents=True, exist_ok=True, mode=0o700)
    for key, url in sources.items():
        if not url:
            continue
        parsed = urlsplit(url)
        if parsed.scheme != 'https' or not (parsed.hostname == 'images.gog.com' or
                re.fullmatch(r'images-\d+\.gog-statics\.com', parsed.hostname or '')):
            continue
        target = cache / hashlib.sha256(url.encode()).hexdigest()
        if not target.is_file():
            with urlopen(url, timeout=20) as response:
                if not response.headers.get('Content-Type', '').startswith('image/'):
                    raise ValueError('Artwork response is not an image')
                data = response.read(8 * 1024 * 1024 + 1)
            if len(data) > 8 * 1024 * 1024:
                raise ValueError('Artwork is too large')
            fd, temporary = tempfile.mkstemp(dir=cache, prefix='.art-')
            try:
                with os.fdopen(fd, 'wb') as output:
                    output.write(data)
                os.replace(temporary, target)
            finally:
                if os.path.exists(temporary):
                    os.unlink(temporary)
        result[key] = url
    return result


def cache_description(item):
    """Cache the official overview for offline library browsing."""
    if isinstance(item.get('description'), str) and item['description'].strip():
        return item
    appid = str(item['id'])
    if not appid.isdecimal():
        raise ValueError('GOG ID must be numeric')
    url = 'https://api.gog.com/products/' + appid + '?expand=description'
    with urlopen(url, timeout=20) as response:
        description = json.load(response).get('description', {})
    text = description.get('lead') or description.get('full') or ''
    # Product pages may put logos, trailers or demo promotions before the overview.
    text = re.sub(r'<(video|script|style)\b[^>]*>.*?</\1>', '', text, flags=re.I | re.S)
    paragraphs = re.split(r'(?:<br\s*/?>\s*){2,}|<hr\b[^>]*>|</?p\b[^>]*>|<h[1-6]\b[^>]*>', text, flags=re.I)
    text = ''
    for paragraph in paragraphs:
        paragraph = ' '.join(unescape(re.sub(r'<[^>]*>', ' ', paragraph)).split())
        if len(paragraph.split()) < 8 or paragraph.lower().startswith('check out') or re.search(r'\bdemo\b.*\bavailable\b', paragraph, re.I):
            continue
        text = paragraph
        break
    return {**item, 'description': text, 'description_source': url}


def refresh_metadata(items, ids=None):
    result = []
    for item in items:
        if ids is None or item['id'] in ids:
            try:
                item = cache_artwork(item)
            except Exception as error:
                print('Artwork unavailable:', item['id'], type(error).__name__, file=sys.stderr)
            try:
                item = cache_description(item)
            except Exception as error:
                print('Description unavailable:', item['id'], type(error).__name__, file=sys.stderr)
        result.append(item)
    save(state_dir() / 'library.json', result)
    return result


def uninstall(appid):
    """Recoverable removal: never delete unknown in-game saves or prefixes."""
    registry = state_dir() / 'installed.json'
    installed = read(registry).get('installed', [])
    record = next((g for g in installed if g['appName'] == appid), None)
    if not record:
        raise ValueError('Game is not registered as installed')
    raw = Path(record['install_path'])
    root = raw.resolve()
    games = (Path.home() / 'Games').resolve()
    if raw.is_symlink() or not root.is_relative_to(games) or root == games or len(root.relative_to(games).parts) < 2:
        raise ValueError('Refusing removal outside a dedicated game directory under ~/Games')
    for other in installed:
        if other['appName'] != appid:
            path = Path(other['install_path']).resolve()
            if path.is_relative_to(root) or root.is_relative_to(path):
                raise ValueError('Installation overlaps another registered game')
    prefix = Path(record.get('prefix', str(Path.home()))).resolve()
    if prefix.is_relative_to(root) or root.is_relative_to(prefix):
        raise ValueError('Installation overlaps its save prefix')
    removed = state_dir() / 'removed' / (appid + '-' + uuid.uuid4().hex)
    removed.mkdir(parents=True, mode=0o700)
    save(removed / 'record.json', record)
    shutil.move(str(root), str(removed / 'files'))
    save(registry, {'installed': [g for g in installed if g['appName'] != appid]})
    print('Uninstalled to recovery storage:', removed)
    print('Saves preserved. Disk space is not reclaimed until recovery files are removed.')


def config_dir():
    return Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config'))) / 'gog'


def state_dir():
    return Path(os.environ.get('XDG_DATA_HOME', str(Path.home() / '.local/share'))) / 'gog'


def read(path, default=None):
    return json.loads(path.read_text()) if path.is_file() else ({} if default is None else default)


def save(path, data):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd, temporary = tempfile.mkstemp(dir=path.parent, prefix='.gog-')
    try:
        with os.fdopen(fd, 'w') as output:
            json.dump(data, output, indent=2)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def estimate_install(downloader, appid, path, platform='windows', language='en-US'):
    response = subprocess.run([downloader, 'info', appid, '--platform', platform,
                               '--lang', language, '--skip-dlcs'], capture_output=True, text=True, check=True)
    info = json.loads(response.stdout)
    if 'size' in info:
        sizes = [info['size'].get('*', {}), info['size'].get(language, {})]
        download = sum(int(s.get('download_size', 0)) for s in sizes)
        installed = sum(int(s.get('disk_size', 0)) for s in sizes)
    else:
        download, installed = int(info['download_size']), int(info['disk_size'])
    if download < 0 or installed <= 0:
        raise ValueError('GOG returned invalid installation sizes')
    filesystem = Path(path).resolve()
    while not filesystem.exists():
        filesystem = filesystem.parent
    free = shutil.disk_usage(filesystem).free
    return {'phase': 'ready', 'download_bytes': download, 'installed_bytes': installed,
            'free_bytes': free, 'path': str(Path(path).resolve()),
            'recommended_free_bytes': installed + download + 512 * 1024 * 1024}


def progress_event(line, status):
    """Parse only known numeric fields; never expose raw logs/URLs in Kodi."""
    if '[PROGRESS]' not in line:
        return False
    number = r'(\d+(?:\.\d+)?)'
    match = re.search(r'Progress: ' + number + r' (\d+)/(\d+),.*ETA: (\d+):(\d+):(\d+)', line)
    if match:
        percent, written, total, hours, minutes, seconds = match.groups()
        status.update(phase='installing', percent=max(0, min(100, float(percent))),
                      written_bytes=int(written), total_write_bytes=int(total),
                      eta_seconds=(int(hours) * 3600 + int(minutes) * 60 + int(seconds)) if float(percent) > 0 else None)
        return True
    match = re.search(r'Downloaded: ' + number + r' MiB', line)
    if match:
        status['downloaded_bytes'] = int(float(match[1]) * 1024 * 1024)
        return True
    match = re.search(r'\+ Download\s+- ' + number + r' MiB/s \(raw\)', line)
    if match:
        status['speed_bytes'] = int(float(match[1]) * 1024 * 1024)
        return True
    return False


def download_with_progress(argv, status_path=None):
    status = read(status_path) if status_path else {}
    status.update(phase='preparing', percent=0)
    if status_path:
        save(status_path, status)
    with subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                          text=True, bufsize=1, env={**os.environ, 'PYTHONUNBUFFERED': '1'}) as process:
        for line in process.stdout:
            print(line, end='', flush=True)  # Detailed output stays in private launch log.
            if progress_event(line, status) and status_path:
                save(status_path, status)
        code = process.wait()
    if code:
        raise subprocess.CalledProcessError(code, argv)
    if status.get('total_write_bytes', 0) > status.get('written_bytes', 0):
        raise ValueError('Downloader stopped before all files were written; retry the installation')
    if status_path:
        save(status_path, {**status, 'phase': 'registering'})


def case_path(root, relative):
    result = root
    for part in str(relative).replace('\\', '/').split('/'):
        if part in ('', '.'):
            continue
        if part == '..':
            raise ValueError('Game metadata escapes its installation')
        exact = result / part
        result = exact if exact.exists() else next((p for p in result.iterdir() if p.name.casefold() == part.casefold()), exact)
    if not result.resolve().is_relative_to(root.resolve()):
        raise ValueError('Game executable escapes its installation')
    return result


def installation_metadata(path, appid=None):
    """Support download roots wrapping the actual installation directory."""
    pattern = 'goggame-' + str(appid) + '.info' if appid else 'goggame-*.info'
    for prefix in ('', '*/', '*/*/'):
        matches = []
        for candidate in sorted(path.glob(prefix + pattern)):
            if not candidate.resolve().is_relative_to(path):
                raise ValueError('GOG metadata escapes its download directory')
            info = read(candidate)
            if info.get('playTasks'):
                matches.append((candidate.parent.resolve(), info))
        if len(matches) > 1:
            raise ValueError('Multiple playable GOG installations found; specify the exact game directory')
        if matches:
            return matches[0]
    raise ValueError('No playable GOG metadata in ' + str(path))


def register(path, appid=None, metadata=None, settings=None):
    download_path = Path(path).resolve()
    path, info = installation_metadata(download_path, appid)
    appid = str(appid or info.get('rootGameId') or info['gameId'])
    settings, metadata = settings or {}, metadata or {}
    task = next((t for t in info['playTasks'] if t.get('isPrimary')), info['playTasks'][0])
    option = settings.get('lastUsedLaunchOption', {})
    override = settings.get('targetExe') or (option.get('executable') if option.get('type') == 'altExe' else None)
    if override:
        executable = Path(override).resolve()
        if not executable.is_relative_to(path):
            raise ValueError('Configured executable outside installation')
        task = next((t for t in info['playTasks'] if str(t.get('path', '')).replace('\\', '/').casefold() == executable.relative_to(path).as_posix().casefold()), {})
    else:
        executable = case_path(path, task['path'])
    if not executable.is_file():
        raise ValueError('Missing executable: ' + str(executable))
    import shlex
    arguments = task.get('arguments', [])
    if isinstance(arguments, str):
        arguments = shlex.split(arguments.replace('\\', '/'))
    return {
        **metadata, 'appName': appid, 'title': metadata.get('title') or info.get('name', path.name),
        'install_path': str(path), 'download_path': (metadata or {}).get('download_path', str(download_path)),
        'executable': str(executable), 'arguments': arguments,
        'working_dir': str(executable.parent if override else case_path(path, task.get('workingDir', ''))),
        'platform': metadata.get('platform', 'windows'),
        'prefix': settings.get('winePrefix') or str(Path.home() / 'Games/Prefixes' / ('gog-' + appid)),
        'environment': {e['key']: e['value'] for e in settings.get('enviromentOptions', []) if e.get('key')},
    }


def migrate(refresh=False):
    heroic = Path.home() / '.config/heroic'
    auth = config_dir() / 'auth.json'
    if not auth.exists() and (heroic / 'gog_store/auth.json').is_file():
        auth.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        shutil.copyfile(heroic / 'gog_store/auth.json', auth)
        auth.chmod(0o600)
    library = read(heroic / 'store_cache/gog_library.json').get('games', [])
    lookup = {str(g['app_name']): g for g in library}
    installed = read(state_dir() / 'installed.json').get('installed', [])
    existing = {str(g['appName']) for g in installed}
    for game in read(heroic / 'gog_store/installed.json').get('installed', []):
        appid = str(game['appName'])
        if (appid in existing and not refresh) or game.get('is_dlc') or not Path(game['install_path']).is_dir():
            continue
        settings = read(heroic / 'GamesConfig' / (appid + '.json')).get(appid, {})
        try:
            item = register(game['install_path'], appid, {**lookup.get(appid, {}), **game}, settings)
        except (OSError, ValueError, KeyError) as error:
            print('Not imported:', appid, str(error), file=sys.stderr)
            continue
        installed = [g for g in installed if str(g['appName']) != appid] + [item]
    save(state_dir() / 'installed.json', {'installed': installed})
    if not (state_dir() / 'library.json').exists():
        save(state_dir() / 'library.json', [{'id': str(g['app_name']), 'title': g.get('title', '')} for g in library])
    for name in ('images-cache', 'icons'):
        source = heroic / name
        if source.is_dir():
            shutil.copytree(source, state_dir() / name, dirs_exist_ok=True)
    print('Imported', len(installed), 'installations; original Heroic data and prefixes preserved.')


def library():
    from gogdl.auth import AuthorizationManager
    from gogdl.api import ApiHandler
    auth = config_dir() / 'auth.json'
    if not auth.is_file():
        raise ValueError('No GOG login. Run gog login or gog migrate-heroic.')
    auth.chmod(0o600)
    manager = AuthorizationManager(str(auth))
    if not manager.get_credentials():
        raise ValueError('GOG login expired. Run gog login.')
    api = ApiHandler(manager)
    previous = {g['id']: g for g in read(state_dir() / 'library.json', [])}
    result, page = [], 1
    while True:
        response = api.session.get('https://embed.gog.com/account/getFilteredProducts',
                                   params={'mediaType': '1', 'page': page, 'sortBy': 'title'}, timeout=20)
        response.raise_for_status()
        data = response.json()
        result.extend({**previous.get(str(g['id']), {}), 'id': str(g['id']), 'title': g['title']} for g in data['products'] if g.get('isGame', True))
        if page >= int(data.get('totalPages', 1)):
            break
        page += 1
    return refresh_metadata(result)


def main():
    parser = argparse.ArgumentParser(description='GOG inventory, downloads and local installation registry')
    parser.add_argument('--gogdl', required=True)
    commands = parser.add_subparsers(dest='command', required=True)
    listing = commands.add_parser('list')
    listing.add_argument('--uninstalled', action='store_true')
    listing.add_argument('--installed', action='store_true')
    listing.add_argument('--offline', action='store_true')
    listing.add_argument('--json', action='store_true')
    migration = commands.add_parser('migrate-heroic')
    migration.add_argument('--refresh', action='store_true', help='Re-import existing launch preferences too')
    commands.add_parser('login')
    metadata = commands.add_parser('metadata', aliases=['artwork'], help='Cache missing artwork and official descriptions for owned games')
    metadata.add_argument('ids', nargs='*')
    importing = commands.add_parser('import')
    importing.add_argument('path')
    install = commands.add_parser('install')
    install.add_argument('id')
    install.add_argument('--path')
    install.add_argument('--lang', default='en-US')
    install.add_argument('--platform', choices=['windows', 'linux'], default='windows')
    install.add_argument('--status-file', type=Path)
    info = commands.add_parser('info', help='Installation estimates and destination free space; no game download')
    info.add_argument('id')
    info.add_argument('--path')
    info.add_argument('--lang', default='en-US')
    info.add_argument('--platform', choices=['windows', 'linux'], default='windows')
    info.add_argument('--status-file', type=Path)
    for name in ('update', 'repair'):
        updating = commands.add_parser(name)
        updating.add_argument('id')
    removing = commands.add_parser('uninstall')
    removing.add_argument('id')
    args = parser.parse_args()
    os.umask(0o077)
    # One CLI writer at a time, including downloads. Crash/cancellation releases
    # the kernel lock automatically; no stale lock-file cleanup is needed.
    state_dir().mkdir(parents=True, exist_ok=True, mode=0o700)
    with (state_dir() / 'operation.lock').open('a') as operation_lock:
        try:
            fcntl.flock(operation_lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise ValueError('Another GOG operation is already running')
        run_command(args)


def run_command(args):
    if args.command == 'info':
        if not args.id.isdecimal():
            raise ValueError('GOG ID must be numeric')
        estimate = estimate_install(args.gogdl, args.id, args.path or str(Path.home() / 'Games/GOG' / args.id), args.platform, args.lang)
        if args.status_file:
            save(args.status_file, estimate)
        print(json.dumps(estimate))
    elif args.command in ('metadata', 'artwork'):
        refresh_metadata(read(state_dir() / 'library.json', []), set(args.ids) if args.ids else None)
    elif args.command == 'uninstall':
        if not args.id.isdecimal():
            raise ValueError('GOG ID must be numeric')
        uninstall(args.id)
    elif args.command == 'migrate-heroic':
        migrate(args.refresh)
    elif args.command == 'import':
        item = register(args.path)
        installed = read(state_dir() / 'installed.json').get('installed', [])
        installed = [g for g in installed if g['appName'] != item['appName']] + [item]
        save(state_dir() / 'installed.json', {'installed': installed})
        print('Registered:', item['title'])
    elif args.command in ('install', 'update', 'repair'):
        if not args.id.isdecimal():
            raise ValueError('GOG ID must be numeric')
        installed = read(state_dir() / 'installed.json').get('installed', [])
        current = next((g for g in installed if g['appName'] == args.id), {})
        if args.command != 'install' and not current:
            raise ValueError('Game is not registered as installed')
        path = getattr(args, 'path', None) or current.get('download_path') or current.get('install_path') or str(Path.home() / 'Games/GOG' / args.id)
        platform = getattr(args, 'platform', None) or current.get('platform', 'windows')
        status_path = getattr(args, 'status_file', None)
        download_with_progress([args.gogdl, 'download' if args.command == 'install' else args.command,
                        args.id, '--path', path, '--platform', platform,
                        '--lang', getattr(args, 'lang', None) or current.get('language', 'en-US'), '--skip-dlcs'], status_path)
        titles = {g['id']: g['title'] for g in read(state_dir() / 'library.json', [])}
        preserve_launch = bool(current) and platform == current.get('platform', 'windows')
        if platform == 'linux':
            install = Path(current['install_path'] if preserve_launch else path).resolve()
            executable = Path(current.get('executable', install / 'start.sh') if preserve_launch else install / 'start.sh').resolve()
            if not executable.is_file() or not executable.is_relative_to(install):
                raise ValueError('Downloaded native game has no valid executable; use gog import with its metadata')
            item = {**current, 'appName': args.id, 'install_path': str(install), 'download_path': str(Path(path).resolve()),
                    'executable': str(executable), 'working_dir': str(executable.parent),
                    'title': titles.get(args.id, args.id), 'platform': 'linux', 'arguments': [],
                    'prefix': current.get('prefix', str(Path.home() / 'Games/Prefixes' / ('gog-' + args.id)))}
        else:
            settings = {'winePrefix': current.get('prefix', '') if preserve_launch else ''}
            if preserve_launch and current.get('executable'):
                settings['targetExe'] = current['executable']
            item = register(path, args.id, {**current, 'platform': platform, 'title': titles.get(args.id, args.id)}, settings)
        if preserve_launch:
            # Refresh installation metadata without resetting local launch
            # choices, including deliberately empty arguments/environment.
            item.update({key: current[key] for key in ('arguments', 'environment', 'working_dir') if key in current})
        save(state_dir() / 'installed.json', {'installed': [g for g in installed if g['appName'] != args.id] + [item]})
        if status_path:
            save(status_path, {**read(status_path), 'phase': 'done', 'percent': 100})
        print('Registered:', item['title'])
    elif args.command == 'login':
        print('Open https://auth.gog.com/auth?client_id=46899977096215655&redirect_uri=https%3A%2F%2Fembed.gog.com%2Fon_login_success%3Forigin%3Dclient&response_type=code')
        from urllib.parse import urlparse, parse_qs
        url = input('Paste the final redirected URL: ').strip()
        code = parse_qs(urlparse(url).query).get('code', [''])[0]
        if not code:
            raise ValueError('No authorization code in URL')
        response = subprocess.run([args.gogdl, 'auth', '--code', code], capture_output=True, text=True, check=True)
        credentials = json.loads(response.stdout)
        if not credentials or credentials.get('error'):
            raise ValueError('GOG login failed')
        print('Logged in. Credentials stored privately, outside Nix.')
    elif args.command == 'list':
        items = read(state_dir() / 'library.json', []) if args.offline else library()
        installed = {str(g['appName']) for g in read(state_dir() / 'installed.json').get('installed', []) if Path(g['install_path']).is_dir()}
        rows = [{**g, 'installed': g['id'] in installed} for g in items]
        rows = [g for g in rows if not args.uninstalled or not g['installed']]
        rows = [g for g in rows if not args.installed or g['installed']]
        if args.json:
            print(json.dumps(rows, indent=2))
        else:
            for g in sorted(rows, key=lambda g: g['title'].casefold()):
                print(g['id'], 'installed' if g['installed'] else 'uninstalled', g['title'], sep='\t')


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        # Never print raw network exceptions or auth responses (may contain tokens).
        print('GOG operation failed:', str(error) if isinstance(error, ValueError) else type(error).__name__, file=sys.stderr)
        sys.exit(1)
