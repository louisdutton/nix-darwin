"""Switch resident Home pages only after their native providers finish."""
import time

PAGES = ('home', 'videos', 'games')
CONTROLS = {'home': 30111, 'videos': 30121, 'games': 30122}
EMPTY_FOCUS = 30110


def switch_page(xbmc, xbmcgui, action):
    # An onload restore can start after the user has already opened a detail
    # screen. It must never take focus back from that newer navigation.
    if action == 'restore' and not xbmc.getCondVisibility('Window.IsActive(Home)'):
        return
    home = xbmcgui.Window(10000)
    current = home.getProperty('LocalHome.Page') or 'home'
    pending = home.getProperty('LocalHome.PageRequest') or current
    if pending not in PAGES:
        pending = 'home'
    if action == 'restore':
        # Restore focus only. A bumper request owns page changes and must not
        # be overwritten by an onload script that starts late.
        monitor = xbmc.Monitor()
        deadline = time.monotonic() + 15
        control = CONTROLS[current]
        while not monitor.abortRequested():
            if (not xbmc.getCondVisibility('Window.IsActive(Home)')
                    or home.getProperty('LocalHome.PageRequest')
                    or (home.getProperty('LocalHome.Page') or 'home') != current):
                return
            ready = current == 'home' or home.getProperty('LocalHome.' + current.title() + 'Ready') == 'true'
            if ready and not xbmc.getCondVisibility(f'Container({control}).IsUpdating'):
                if not xbmc.getCondVisibility(f'Integer.IsGreater(Container({control}).NumItems,0)'):
                    control = EMPTY_FOCUS
                xbmc.executebuiltin(f'SetFocus({control})')
                return
            if time.monotonic() >= deadline or monitor.waitForAbort(0.025):
                return
        return
    if action in ('next', 'previous'):
        page = PAGES[(PAGES.index(pending) + (1 if action == 'next' else -1)) % len(PAGES)]
    elif action in PAGES:
        page = action
    elif action == 'back':
        if current == 'home':
            control = CONTROLS['home'] if xbmc.getCondVisibility(
                'Integer.IsGreater(Container(30111).NumItems,0)') else EMPTY_FOCUS
            xbmc.executebuiltin(f'SetFocus({control})')
            return
        page = 'home'
    else:
        return
    home.setProperty('LocalHome.PageRequest', page)
    if not xbmc.getCondVisibility('Window.IsActive(Home)'):
        xbmc.executebuiltin('ActivateWindow(Home)')
    monitor = xbmc.Monitor()
    deadline = time.monotonic() + 15
    control = CONTROLS[page]
    # The old page remains visible. A newer bumper request supersedes this one.
    while not monitor.abortRequested():
        if home.getProperty('LocalHome.PageRequest') != page:
            return
        active = xbmc.getCondVisibility('Window.IsActive(Home)')
        ready = page == 'home' or home.getProperty('LocalHome.' + page.title() + 'Ready') == 'true'
        if active and ready and not xbmc.getCondVisibility(f'Container({control}).IsUpdating'):
            motion = page + '.' + action if action in ('next', 'previous') and page != current else ''
            home.setProperty('LocalHome.PageMotion', motion)
            home.setProperty('LocalHome.Page', page)
            if not xbmc.getCondVisibility(f'Integer.IsGreater(Container({control}).NumItems,0)'):
                control = EMPTY_FOCUS
            xbmc.executebuiltin(f'SetFocus({control})')
            home.clearProperty('LocalHome.PageRequest')
            return
        if time.monotonic() >= deadline:
            xbmc.log('Local Home: page provider did not finish: ' + page, xbmc.LOGERROR)
            home.clearProperty('LocalHome.PageRequest')
            return
        if monitor.waitForAbort(0.025):
            return
