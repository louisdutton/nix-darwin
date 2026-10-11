"""One local activity rail; Kodi remains the authority for all video history."""
from contextlib import closing
from datetime import datetime
import json
from pathlib import Path
import sqlite3
import time


def history_path():
    import xbmcvfs
    return Path(xbmcvfs.translatePath(
        'special://profile/addon_data/plugin.program.localhome/activity.sqlite'))


def record_game(appid, path=None, opened=None):
    path = Path(path) if path is not None else history_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    with closing(sqlite3.connect(path, timeout=5)) as db, db:
        db.execute('CREATE TABLE IF NOT EXISTS games (id TEXT PRIMARY KEY, opened REAL NOT NULL)')
        db.execute('INSERT OR REPLACE INTO games VALUES (?, ?)',
                   (appid, time.time() if opened is None else opened))


def game_history(path=None):
    path = Path(path) if path is not None else history_path()
    if not path.is_file():
        return {}
    try:
        with closing(sqlite3.connect(path, timeout=5)) as db:
            return dict(db.execute('SELECT id, opened FROM games'))
    except sqlite3.Error:
        return {}


def timestamp(value):
    try:
        return datetime.fromisoformat(value).timestamp()
    except (ValueError, TypeError):
        return 0


def select_items(movies, episodes, games, history):
    items = []
    for movie in movies:
        opened = timestamp(movie.get('lastplayed'))
        if opened and movie.get('resume', {}).get('position', 0) > 0 and movie.get('file', '').startswith('/'):
            items.append({'kind': 'movie', 'opened': opened, 'media': movie})
    shows = {}
    for episode in episodes:
        if episode.get('file', '').startswith('/'):
            shows.setdefault(episode['tvshowid'], []).append(episode)
    for entries in shows.values():
        latest = max(entries, key=lambda e: timestamp(e.get('lastplayed')))
        opened = timestamp(latest.get('lastplayed'))
        if not opened:
            continue
        key = lambda e: (e['season'], e['episode'])
        if latest.get('resume', {}).get('position', 0) > 0 or not latest.get('playcount', 0):
            target = latest
        else:
            following = [e for e in entries if key(e) > key(latest) and not e.get('playcount', 0)
                         and (e['season'] > 0 or latest['season'] == 0)]
            if not following:
                continue
            target = min(following, key=key)
        items.append({'kind': 'episode', 'opened': opened, 'media': target})
    for appid, opened in history.items():
        if appid in games and games[appid].get('installed', True):
            items.append({'kind': 'game', 'opened': opened, 'id': appid, 'media': games[appid]})
    return sorted(items, key=lambda item: (-item['opened'], item['kind'], item['media']['title']))


def library_items(games):
    import xbmc
    def query(method, key, properties):
        response = json.loads(xbmc.executeJSONRPC(json.dumps({
            'jsonrpc': '2.0', 'id': 1, 'method': method,
            'params': {'properties': properties}})))
        if 'error' in response:
            raise RuntimeError('Could not read Kodi viewing history: ' + str(response['error']))
        return response.get('result', {}).get(key, [])
    common = ['title', 'file', 'art', 'plot', 'resume', 'lastplayed', 'playcount']
    return select_items(query('VideoLibrary.GetMovies', 'movies', common + ['year']),
                        query('VideoLibrary.GetEpisodes', 'episodes',
                              common + ['season', 'episode', 'tvshowid', 'showtitle']),
                        games, game_history())


def refresh():
    import xbmcgui
    home = xbmcgui.Window(10000)
    generation = str(time.time_ns())
    home.setProperty('LocalHome.ContinueReload', generation)
    home.setProperty('LocalHome.VideosReload', generation)


def watch_playback():
    import xbmc
    import threading
    changed = threading.Event()
    class HistoryPlayer(xbmc.Player):
        def onPlayBackStopped(self):
            changed.set()

        def onPlayBackEnded(self):
            changed.set()
    class HistoryMonitor(xbmc.Monitor):
        def onNotification(self, sender, method, data):
            if method in ('VideoLibrary.OnUpdate', 'VideoLibrary.OnRemove',
                          'VideoLibrary.OnScanFinished'):
                changed.set()
    player = HistoryPlayer()  # Keep the callback object alive until shutdown.
    monitor = HistoryMonitor()
    # Coalesce native events rather than polling/re-writing video history.
    while not monitor.waitForAbort(0.25):
        # Only the simple playback bar auto-hides; never dismiss its audio or
        # subtitle subdialogs, and keep controls visible when paused.
        if (xbmc.getCondVisibility('Window.IsDialogTopmost(VideoOSD)')
                and not xbmc.getCondVisibility('Player.Paused')
                and xbmc.getGlobalIdleTime() >= 5):
            xbmc.executebuiltin('Dialog.Close(VideoOSD)')
        if changed.is_set():
            changed.clear()
            refresh()
