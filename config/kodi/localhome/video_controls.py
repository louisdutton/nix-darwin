"""Small playback actions; native Kodi owns resume points and episode browsing."""
import json
import sys


def open_episode(xbmc, xbmcgui, episodeid):
    response = json.loads(xbmc.executeJSONRPC(json.dumps({
        'jsonrpc': '2.0', 'id': 1, 'method': 'VideoLibrary.GetEpisodeDetails',
        'params': {'episodeid': int(episodeid), 'properties': ['tvshowid', 'file']}})))
    episode = response.get('result', {}).get('episodedetails', {})
    show = episode.get('tvshowid')
    if not isinstance(show, int) or show <= 0 or not episode.get('file', '').startswith('/'):
        return
    # Native Kodi owns the episode list, sorting, resume points and Back history.
    xbmc.executebuiltin(f'ActivateWindow(Videos,videodb://tvshows/titles/{show}/,return)', True)
    monitor = xbmc.Monitor()
    for _ in range(100):
        if not xbmc.getCondVisibility('Window.IsActive(Videos)'):
            return
        if xbmc.getCondVisibility('Container.Content(episodes) + !Container(50).IsUpdating'):
            count = xbmc.getInfoLabel('Container(50).NumItems')
            if count.isdecimal():
                # NumItems excludes the optional parent row. Absolute indices
                # include it; match the actual displayed item rather than
                # assuming an episode number or database query order.
                for index in range(int(count) + 1):
                    item = f'Container(50).ListItemAbsolute({index})'
                    if (xbmc.getInfoLabel(item + '.DBTYPE') == 'episode'
                            and xbmc.getInfoLabel(item + '.DBID') == str(episodeid)):
                        window = xbmcgui.Window(10025)
                        window.getControl(50).selectItem(index)
                        window.setFocusId(50)
                        return
        if monitor.waitForAbort(0.05):
            return


def leave_player(xbmc):
    player = xbmc.Player()
    if not player.isPlayingVideo():
        return
    if xbmc.getCondVisibility('Window.Previous(Videos)'):
        xbmc.executebuiltin('Dialog.Close(VideoOSD,true)')
        player.stop()
        return
    tag = player.getVideoInfoTag()
    show = None
    if tag.getMediaType() == 'episode' and tag.getDbId() > 0:
        response = json.loads(xbmc.executeJSONRPC(json.dumps({
            'jsonrpc': '2.0', 'id': 1, 'method': 'VideoLibrary.GetEpisodeDetails',
            'params': {'episodeid': tag.getDbId(), 'properties': ['tvshowid']}})))
        show = response.get('result', {}).get('episodedetails', {}).get('tvshowid')
    xbmc.executebuiltin('Dialog.Close(VideoOSD,true)')
    player.stop()
    # Wait for the native stop/return-to-window hand-off before navigating.
    monitor = xbmc.Monitor()
    for _ in range(100):
        if not player.isPlayingVideo():
            break
        if monitor.waitForAbort(0.05):
            return
    else:
        return  # Never leave playback running behind a library window.
    if isinstance(show, int) and show > 0:
        # Stopping from Home starts its native widget refresh. Closing that
        # window while providers are still starting can deadlock Kodi's GUI
        # against a provider's JSON-RPC call. Allow the normal window fade and
        # require a short run of idle provider frames before leaving Home.
        idle = 0
        for _ in range(50):
            if monitor.waitForAbort(0.1):
                return
            busy = xbmc.getCondVisibility(
                'Window.IsActive(Home) + [Container(30111).IsUpdating | '
                'Container(30121).IsUpdating | Container(30122).IsUpdating]')
            idle = 0 if busy else idle + 1
            if idle >= 3:
                break
        else:
            return
        xbmc.executebuiltin(f'ActivateWindow(Videos,videodb://tvshows/titles/{show}/,return)')


if __name__ == '__main__':
    import xbmc
    if len(sys.argv) > 1 and sys.argv[1] == 'back':
        leave_player(xbmc)
