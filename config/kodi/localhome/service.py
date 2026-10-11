"""Idempotently assign local-only content types, then scan declared sources."""
import json
from pathlib import Path
import sqlite3
import threading

import xbmc
import xbmcvfs


def configure_sources(database, sources):
    """Touch only source configuration rows, never media or watch-history rows."""
    required = {'idPath', 'strPath', 'strContent', 'strScraper', 'scanRecursive',
                'useFolderNames', 'strSettings', 'noUpdate', 'exclude', 'allAudio'}
    with sqlite3.connect(database, timeout=5) as connection:
        columns = {row[1] for row in connection.execute('PRAGMA table_info(path)')}
        if not required <= columns:
            raise RuntimeError('Unsupported Kodi path-table schema')
        for source in sources:
            path, content = source['path'], source['content']
            current = connection.execute(
                'SELECT idPath,strContent,strScraper,scanRecursive,useFolderNames,'
                'strSettings,noUpdate,exclude,allAudio FROM path WHERE strPath=?', (path,)).fetchone()
            if current is None:
                connection.execute(
                    'INSERT INTO path (strPath,strContent,strScraper,scanRecursive,'
                    'useFolderNames,strSettings,noUpdate,exclude,allAudio) '
                    'VALUES (?,?,?,0,0,?,0,0,0)', (path, content, 'metadata.local', ''))
            elif current[1:] != (content, 'metadata.local', 0, 0, '', 0, 0, 0):
                connection.execute(
                    'UPDATE path SET strContent=?,strScraper=?,scanRecursive=0,'
                    'useFolderNames=0,strSettings=?,noUpdate=0,exclude=0,allAudio=0 '
                    'WHERE idPath=?', (content, 'metadata.local', '', current[0]))


def configure_media():
    sources = json.loads((Path(__file__).parent / 'media-sources.json').read_text(encoding='utf-8'))
    databases = Path(xbmcvfs.translatePath('special://database'))
    monitor = xbmc.Monitor()
    for _ in range(30):
        candidates = [p for p in databases.glob('MyVideos*.db')
                      if p.stem.removeprefix('MyVideos').isdecimal()]
        if candidates:
            database = max(candidates, key=lambda p: int(p.stem.removeprefix('MyVideos')))
            try:
                configure_sources(database, sources)
                xbmc.log('Local Home: configured local-only media sources', xbmc.LOGINFO)
                # Let the startup screen and widget compilation finish first.
                if not monitor.waitForAbort(3):
                    for source in sources:
                        xbmc.executeJSONRPC(json.dumps({
                            'jsonrpc': '2.0', 'id': 1, 'method': 'VideoLibrary.Scan',
                            'params': {'directory': source['path'], 'showdialogs': False}}))
                        if monitor.waitForAbort(0.5):
                            return
                        while xbmc.getCondVisibility('Library.IsScanningVideo'):
                            if monitor.waitForAbort(0.5):
                                return
                return
            except (sqlite3.Error, RuntimeError) as error:
                xbmc.log('Local Home: waiting for video database: ' + str(error), xbmc.LOGWARNING)
        if monitor.waitForAbort(1):
            return
    xbmc.log('Local Home: source configuration timed out; database left intact', xbmc.LOGERROR)


def main():
    from input_router import main as route_input
    from continue_watching import watch_playback
    threading.Thread(target=configure_media, daemon=True).start()
    threading.Thread(target=watch_playback, daemon=True).start()
    route_input()


if __name__ == '__main__':
    main()
