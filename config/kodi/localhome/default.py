"""Local widgets and owned independent launches of explicitly installed games."""
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import parse_qs, urlencode, urlsplit

import xbmc
import xbmcgui
import xbmcplugin
PAGE_ACTION = len(sys.argv) > 2 and sys.argv[1] == 'page'
if not PAGE_ACTION:
    from game_session import run_game
    from standalone import launch_config, custom_launch, gog_launch, prepare_game
    from owned_launch import OwnedLaunch
    from game_session import TOOLS

BASE = 'plugin://plugin.program.localhome/'
STEAM = Path.home() / '.local/share/Steam'
FILMS = Path.home() / 'Videos/Films'
HEROIC = Path.home() / '.config/heroic'
GOG = Path.home() / '.local/share/gog'
ARTWORK_CACHE = Path.home() / '.cache/kodi-localhome/artwork'


def read_json(path):
    try:
        return json.loads(Path(path).read_text(encoding='utf-8'))
    except (OSError, ValueError):
        return {}


def cached_game_image(url):
    if not isinstance(url, str) or not url:
        return None
    digest = hashlib.sha256(url.encode()).hexdigest()
    cached = GOG / 'images-cache' / digest
    if not cached.is_file():
        cached = HEROIC / 'images-cache' / digest
    if not cached.is_file():
        return None
    # Heroic stores extensionless files. Kodi's skin helpers can treat those
    # as directories; give the same image an extension without modifying it.
    extension = Path(urlsplit(url).path).suffix.lower()
    if extension not in ('.jpg', '.jpeg', '.png', '.webp', '.gif'):
        return str(cached)
    try:
        ARTWORK_CACHE.mkdir(parents=True, exist_ok=True)
        link = ARTWORK_CACHE / (digest + extension)
        if not link.is_symlink() and not link.exists():
            try:
                link.symlink_to(cached)
            except FileExistsError:
                pass  # Two widget refreshes can request the same image.
        return str(link)
    except OSError:
        return str(cached)


def gog_art(game, appid):
    art = {}
    # GOG's art_square is portrait box art; art_cover is a wide store banner.
    for kodi_key, source_key in [('poster', 'art_square'), ('thumb', 'art_cover'),
                                ('fanart', 'art_background')]:
        cached = cached_game_image(game.get(source_key, ''))
        if cached:
            art[kodi_key] = cached
    icon = GOG / 'icons' / (appid + '.png')
    if not icon.is_file():
        icon = HEROIC / 'icons' / (appid + '.png')
    art.setdefault('thumb', str(icon) if icon.is_file() else 'DefaultAddonGame.png')
    art.setdefault('poster', art['thumb'])
    return art


def installed_gog_games():
    games = {}
    library = read_json(GOG / 'library.json')
    artwork = {str(g['id']): g for g in library} if isinstance(library, list) else {}
    for record in read_json(GOG / 'installed.json').get('installed', []):
        appid = str(record.get('appName', ''))
        if not appid.isdecimal() or not Path(record.get('install_path', '/nonexistent')).is_dir():
            continue
        metadata = {**record, **artwork.get(appid, {})}
        game = {'title': record.get('title', appid), 'installed': True,
                'description': metadata.get('description', ''), 'art': gog_art(metadata, appid)}
        try:
            game.update(gog_launch(record, TOOLS))
        except (OSError, RuntimeError, KeyError) as error:
            game.update({'source': 'GOG (unavailable)', 'launch_error': str(error)})
        games['gog:' + appid] = game
    return games


def owned_gog_games():
    library = read_json(GOG / 'library.json')
    if not isinstance(library, list):
        return {}
    old = read_json(HEROIC / 'store_cache/gog_library.json')
    art = {str(g.get('app_name')): g for g in old.get('games', [])} if isinstance(old, dict) else {}
    return {'gog:' + str(g['id']): {
        'title': g.get('title', str(g['id'])), 'installed': False,
        'description': g.get('description', ''),
        'source': 'GOG (not installed)', 'art': gog_art({**art.get(str(g['id']), {}), **g}, str(g['id']))}
        for g in library if isinstance(g, dict) and str(g.get('id', '')).isdecimal()}


def game_catalog():
    games = {appid: {'title': name, 'source': 'Standalone (unconfigured)', 'art': local_art(appid),
                     'launch_error': 'No independent executable declared; Steam launch is disabled'}
             for appid, name in installed_games().items() if re.fullmatch(r'[0-9]+', appid)}
    declarations = read_json(Path(__file__).with_name('game-launches.json'))
    records = installed_steam_records() if declarations else {}
    for appid, declaration in declarations.items():
        if appid.startswith('custom:'):
            games[appid] = {'title': declaration['title'], 'description': declaration.get('description', ''),
                            'art': declaration.get('art', local_art(appid)), 'source': 'Custom game'}
            try:
                games[appid].update(custom_launch(declaration))
            except (OSError, RuntimeError, KeyError) as error:
                games[appid]['launch_error'] = str(error)
        elif appid in games and appid in records:
            games[appid].update({
                'title': declaration.get('title', games[appid]['title']),
                'description': declaration.get('description', ''),
            })
            try:
                games[appid].update(launch_config(appid, declaration, records[appid]['path'], STEAM, TOOLS))
                games[appid].pop('launch_error', None)
            except (OSError, RuntimeError, KeyError) as error:
                # Never silently fall back to the vendor client.
                games[appid].update({'source': 'Standalone (unavailable)', 'launch_error': str(error)})
    games.update(owned_gog_games())
    games.update(installed_gog_games())
    return games


def sorted_games(games):
    return sorted(games.items(), key=lambda pair: (
        not pair[1].get('installed', True), pair[1]['title'].casefold()))


def installed_steam_records():
    roots = {STEAM}
    folders = STEAM / 'steamapps/libraryfolders.vdf'
    if folders.is_file():
        roots.update(Path(p.replace('\\\\', '\\')) for p in
                     re.findall(r'"path"\s+"([^"]+)"', folders.read_text(encoding='utf-8')))
    games = {}
    for root in roots:
        for manifest in (root / 'steamapps').glob('appmanifest_*.acf'):
            fields = dict(re.findall(r'"([^"\n]+)"\s+"([^"\n]*)"', manifest.read_text(encoding='utf-8')))
            appid = fields.get('appid', '')
            name = fields.get('name', '')
            if not appid.isdecimal() or not int(fields.get('StateFlags', '0')) & 4:
                continue
            if name.startswith(('Proton ', 'Steam Linux Runtime', 'Steamworks ')):
                continue
            if name == 'Skyrim Script Extender (SKSE)':
                continue
            if not (root / 'steamapps/common' / fields.get('installdir', '')).is_dir():
                continue
            games[appid] = {'name': name, 'path': str(root / 'steamapps/common' / fields.get('installdir', ''))}
    return games


def installed_games():
    return {appid: game['name'] for appid, game in installed_steam_records().items()}


def local_art(appid):
    cache = STEAM / 'appcache/librarycache' / appid
    art = {}
    for key, filenames in [('poster', ('library_capsule.jpg', 'library_600x900.jpg')),
                           ('fanart', ('library_hero.jpg',)),
                           ('thumb', ('header.jpg', 'library_header.jpg'))]:
        candidates = [p for filename in filenames
                      for p in sorted(cache.rglob(filename)) if p.is_file()]
        if candidates:
            art[key] = str(candidates[0])
    art.setdefault('thumb', 'DefaultAddonGame.png')
    art.setdefault('poster', art['thumb'])
    return art


def launch_game(appid, supervised=False):
    # Only declared installed executables run, through pinned runtime tools.
    # Inherit Kodi's X11 environment, never use a vendor-client fallback.
    games = game_catalog()
    if appid not in games:
        xbmcgui.Dialog().notification('Games', 'This game is not installed')
        return False
    if games[appid].get('installed') is False:
        xbmc.executebuiltin('RunScript(' + str(Path(__file__).with_name('game_manager.py')) + ',install,' + appid + ')')
        return True
    if games[appid].get('launch_error'):
        xbmcgui.Dialog().notification('Games', games[appid]['launch_error'], time=8000)
        return False
    if not supervised:
        # A separate Kodi script owns the progress/input lifecycle; the widget
        # directory request can finish normally without keeping its busy UI up.
        script = str(Path(__file__).with_name('game_session.py'))
        xbmc.executebuiltin('RunScript(' + script + ',' + appid + ')')
        return True
    try:
        def spawn():
            prepare_game(games[appid])
            return OwnedLaunch(games[appid], TOOLS)
        return run_game(appid, games[appid], spawn)
    except (OSError, RuntimeError, subprocess.SubprocessError, KeyError) as error:
        xbmc.log('Local Home: game launch failed: ' + str(error), xbmc.LOGERROR)
        xbmcgui.Dialog().notification('Games', 'Could not start ' + games[appid]['source'])
        return False


def game_item_info(item, title, description, appid=None, installed=True):
    # These are executable launch actions, not videos or RetroPlayer ROMs.
    # A video tag makes Kodi offer queue/play-next and watch-state actions.
    tag = item.getGameInfoTag()
    tag.setTitle(title)
    tag.setOverview(description)
    item.setProperty('IsPlayable', 'false')
    if appid:
        actions = [('More info', 'RunScript(' + str(Path(__file__)) + ',info,' + appid + ')')]
        if appid.startswith('gog:'):
            action = 'uninstall' if installed else 'install'
            script = str(Path(__file__).with_name('game_manager.py'))
            actions.append((action.title(), 'RunScript(' + script + ',' + action + ',' + appid + ')'))
        # Kodi replaces the list on each call; submit all relevant actions once.
        item.addContextMenuItems(actions)


def wrap_inspector_title(title, measure, width):
    """Keep at most two measured lines, with an ellipsis for omitted text."""
    lines, current = [], ''
    for word in title.split():
        candidate = (current + ' ' + word).strip()
        if current and measure(candidate) > width:
            lines.append(current)
            current = word
        else:
            current = candidate
    if current:
        lines.append(current)
    overflow = len(lines) > 2
    lines = lines[:2]
    for index, line in enumerate(lines):
        if measure(line) > width or (overflow and index == len(lines) - 1):
            while line and measure(line + '…') > width:
                line = line[:-1].rstrip()
            lines[index] = line + '…'
    return '[CR]'.join(lines)


def inspector_title(title):
    """Use the inspector's declared geometry and font for title truncation."""
    from PIL import ImageFont
    import xml.etree.ElementTree as ET
    skin = Path(__file__).parent.parent / 'skin.theatre'
    control = ET.parse(skin / '1080i/custom_1100_GameInfo.xml').find(".//control[@id='31100']")
    font = next(f for f in ET.parse(skin / '1080i/Font.xml').findall('.//font')
                if f.findtext('name') == control.findtext('font'))
    face = ImageFont.truetype(str(skin / 'fonts' / font.findtext('filename')), int(font.findtext('size')))
    # Leave a little room for Kodi's pixel rounding at different TV resolutions.
    return wrap_inspector_title(title, face.getlength, int(control.findtext('width')) - 32)


def game_background(appid, art):
    # GOG's background is already faded; use its sharp wide cover and let the
    # skin apply the same crop and gradient as it does for other artwork.
    if appid.startswith('gog:') and art.get('thumb', '').startswith('/'):
        return art['thumb']
    return art.get('fanart') or (art.get('thumb', '') if art.get('thumb', '').startswith('/') else '')


def show_game_info(appid):
    game = game_catalog().get(appid)
    if not game:
        xbmcgui.Dialog().notification('Games', 'Game is no longer in the local catalogue')
        return
    home = xbmcgui.Window(10000)
    installed = game.get('installed', True)
    art = game.get('art', {})
    fields = {
        'Id': appid, 'Title': inspector_title(game['title']),
        'Action': 'Launch' if installed else 'Install',
        'Description': game.get('description') or game.get('plot') or '',
        'Error': game.get('launch_error', ''),
        'Poster': art.get('poster', art.get('thumb', 'DefaultAddonGame.png')),
        'Fanart': game_background(appid, art),
        'CanUninstall': 'true' if installed and appid.startswith('gog:') else 'false',
    }
    for key, value in fields.items():
        home.setProperty('LocalHome.GameInfo.' + key, str(value))
    xbmc.executebuiltin('ActivateWindow(11100)')


def main():
    if len(sys.argv) > 2 and sys.argv[1] == 'episode':
        from video_controls import open_episode
        open_episode(xbmc, xbmcgui, sys.argv[2])
        return
    if len(sys.argv) > 1 and sys.argv[1] == 'back':
        from video_controls import leave_player
        leave_player(xbmc)
        return
    if len(sys.argv) > 2 and sys.argv[1] == 'info':
        show_game_info(sys.argv[2])
        return
    if len(sys.argv) > 2 and sys.argv[1] == 'gameaction':
        xbmc.executebuiltin('Action(Back)')
        launch_game(sys.argv[2])
        return
    if len(sys.argv) > 2 and sys.argv[1] == 'gameuninstall':
        xbmc.executebuiltin('Action(Back)')
        script = str(Path(__file__).with_name('game_manager.py'))
        xbmc.executebuiltin('RunScript(' + script + ',uninstall,' + sys.argv[2] + ')')
        return
    handle = int(sys.argv[1])
    params = parse_qs(sys.argv[2].lstrip('?'))
    if params.get('manage') == ['refresh']:
        xbmc.executebuiltin('RunScript(' + str(Path(__file__).with_name('game_manager.py')) + ',refresh)')
        return
    if params.get('inspect'):
        show_game_info(params['inspect'][0])
        return
    appid = params.get('launch', [''])[0]
    if appid:
        launch_game(appid)
        return
    section = params.get('section', ['films'])[0]
    if params.get('widget') == ['1'] and section in ('library', 'games'):
        page = 'Videos' if section == 'library' else 'Games'
        xbmcgui.Window(10000).setProperty('LocalHome.' + page + 'Ready', 'false')
    if section == 'continue':
        from continue_watching import library_items
        xbmcplugin.setContent(handle, 'videos')
        for entry in library_items(game_catalog()):
            media, kind = entry['media'], entry['kind']
            title = media['title']
            if kind == 'episode':
                title = f"{media['showtitle']} · S{media['season']:02}E{media['episode']:02} — {title}"
            item = xbmcgui.ListItem(title)
            item.setProperty('hide_add_remove_favourite', 'true')
            art = dict(media.get('art', {}))
            art.setdefault('poster', art.get('tvshow.poster', art.get('thumb', 'DefaultVideo.png')))
            if kind == 'game':
                art['fanart'] = game_background(entry['id'], art)
            else:
                art['fanart'] = art.get('fanart') or art.get('tvshow.fanart') or art.get('thumb', '')
            item.setArt(art)
            if kind == 'game':
                game_item_info(item, title, media.get('description', ''), entry['id'])
                item.setProperty('LocalHome.Installed', 'true')
                url = BASE + '?' + urlencode({'inspect': entry['id']})
            else:
                info = {'title': title, 'mediatype': kind, 'dbid': media[kind + 'id'],
                        'plot': media.get('plot', '')}
                for key in ('season', 'episode', 'showtitle', 'year'):
                    if key in media:
                        info['tvshowtitle' if key == 'showtitle' else key] = media[key]
                item.setInfo('video', info)
                resume = media.get('resume', {})
                item.getVideoInfoTag().setResumePoint(resume.get('position', 0), resume.get('total', 0))
                item.setProperty('IsPlayable', 'true')
                url = media['file']
            xbmcplugin.addDirectoryItem(handle, url, item, False)
    elif section == 'games':
        xbmcplugin.setContent(handle, 'games')
        for appid, game in sorted_games(game_catalog()):
            installed = game.get('installed', True)
            label = game['title'] if installed else '[COLOR gray]' + game['title'] + ' · Install[/COLOR]'
            item = xbmcgui.ListItem(label)
            item.setProperty('hide_add_remove_favourite', 'true')
            item.setArt(game['art'])
            item.setProperty('LocalHome.Installed', 'true' if installed else 'false')
            game_item_info(item, game['title'], game.get('description', ''), appid, installed)
            xbmcplugin.addDirectoryItem(handle, BASE + '?' + urlencode({'inspect': appid}), item, False)
        refresh = xbmcgui.ListItem('Refresh owned GOG library')
        refresh.setProperty('hide_add_remove_favourite', 'true')
        refresh.setProperty('IsPlayable', 'false')
        refresh.setArt({'thumb': 'DefaultAddonGame.png'})
        xbmcplugin.addDirectoryItem(handle, BASE + '?manage=refresh', refresh, False)
    elif section == 'library':
        xbmcplugin.setContent(handle, 'videos')
        for kind, media in library_entries():
            item = xbmcgui.ListItem(media['title'])
            item.setProperty('hide_add_remove_favourite', 'true')
            item.setArt(media.get('art', {}))
            item.setInfo('video', {'title': media['title'], 'mediatype': kind,
                                  'dbid': media[kind + 'id'], 'plot': media.get('plot', ''),
                                  'year': media.get('year', 0)})
            folder = kind == 'tvshow'
            if folder:
                url = 'videodb://tvshows/titles/' + str(media['tvshowid']) + '/'
            else:
                url = media['file']
                item.setProperty('IsPlayable', 'true')
                resume = media.get('resume', {})
                item.getVideoInfoTag().setResumePoint(resume.get('position', 0), resume.get('total', 0))
            xbmcplugin.addDirectoryItem(handle, url, item, folder)
    else:
        xbmcplugin.setContent(handle, 'movies')
        result = json.loads(xbmc.executeJSONRPC(json.dumps({
            'jsonrpc': '2.0', 'id': 1, 'method': 'VideoLibrary.GetMovies',
            'params': {'properties': ['title', 'file', 'art', 'plot', 'year'],
                       'sort': {'method': 'title', 'order': 'ascending'}}})))
        movies = result.get('result', {}).get('movies', [])
        for movie in movies:
            item = xbmcgui.ListItem(movie['title'])
            item.setProperty('hide_add_remove_favourite', 'true')
            item.setArt(movie.get('art', {}))
            item.setInfo('video', {'title': movie['title'], 'mediatype': 'movie',
                                  'dbid': movie['movieid'], 'plot': movie.get('plot', ''),
                                  'year': movie.get('year', 0)})
            item.setProperty('IsPlayable', 'true')
            xbmcplugin.addDirectoryItem(handle, movie['file'], item, False)
        if not movies:
            item = xbmcgui.ListItem('No local films yet')
            item.setProperty('hide_add_remove_favourite', 'true')
            item.setArt({'poster': 'DefaultMovies.png', 'thumb': 'DefaultMovies.png'})
            item.setInfo('video', {'title': 'No local films yet',
                                  'plot': 'Add films to ' + str(FILMS) + ' and update the library.'})
            xbmcplugin.addDirectoryItem(handle, str(FILMS) + '/', item, True)
    if section in ('library', 'games'):
        xbmcplugin.setPluginCategory(handle, 'Videos' if section == 'library' else 'Games')
        # Keep our alphabetical / installed-first ordering even if a previous
        # native window view-state selected another sort method.
        xbmcplugin.addSortMethod(handle, xbmcplugin.SORT_METHOD_NONE)
    xbmcplugin.setProperty(handle, 'LocalHome.Ready', 'true')
    if params.get('widget') == ['1'] and section in ('library', 'games'):
        page = 'Videos' if section == 'library' else 'Games'
        xbmcgui.Window(10000).setProperty('LocalHome.' + page + 'Ready', 'true')
    xbmcplugin.endOfDirectory(handle, cacheToDisc=False)


def library_entries():
    entries = []
    for kind, method, key, properties in (
            ('movie', 'VideoLibrary.GetMovies', 'movies', ['title', 'file', 'art', 'plot', 'year', 'resume']),
            ('tvshow', 'VideoLibrary.GetTVShows', 'tvshows', ['title', 'art', 'plot', 'year'])):
        result = json.loads(xbmc.executeJSONRPC(json.dumps({
            'jsonrpc': '2.0', 'id': 1, 'method': method, 'params': {'properties': properties}})))
        if 'error' in result:
            raise RuntimeError('Could not read Kodi local library: ' + str(result['error']))
        entries.extend((kind, media) for media in result.get('result', {}).get(key, [])
                       if kind == 'tvshow' or media.get('file', '').startswith('/'))
    return sorted(entries, key=lambda entry: (entry[1]['title'].casefold(), entry[0]))


if __name__ == '__main__':
    if PAGE_ACTION:
        from navigation import switch_page
        switch_page(xbmc, xbmcgui, sys.argv[2])
    else:
        main()
