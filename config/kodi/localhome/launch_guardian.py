"""Runs inside a private systemd service; Kodi death ends the whole cgroup."""
import os
import ctypes
from pathlib import Path
import select
import subprocess
import sys


def main(owner, argv):
    if argv[:1] == ['SteamLaunch']:
        if ctypes.CDLL(None).prctl(15, b'reaper', 0, 0, 0):
            raise OSError('Could not identify the game to Gamescope')
        argv = argv[argv.index('--') + 1:]
    # A pidfd cannot accidentally attach to a reused Kodi PID.
    descriptor = os.pidfd_open(int(owner))
    membership = Path('/proc/self/cgroup').read_text()
    group = next(line[3:] for line in membership.splitlines() if line.startswith('0::'))
    processes = Path('/sys/fs/cgroup') / group.lstrip('/') / 'cgroup.procs'
    child = None
    try:
        if select.select([descriptor], [], [], 0)[0]:
            return 1
        child = subprocess.Popen(argv)
        while not select.select([descriptor], [], [], 0.2)[0]:
            members = {int(pid) for pid in processes.read_text().split()} - {os.getpid()}
            for pid in members:
                try:
                    if Path('/proc', str(pid), 'comm').read_text().strip() in ('steam', 'steamwebhelper'):
                        print('Unsupported game: attempted to start the Steam client.', flush=True)
                        return 78
                except OSError:
                    pass
            result = child.poll()
            # A launcher can exit after spawning a child. Keep ownership until
            # every descendant is gone, not merely until its initial PID exits.
            if result is not None:
                if not members:
                    return result
        return 1
    finally:
        os.close(descriptor)
        # systemd KillMode=control-group cleans all descendants on our exit.


if __name__ == '__main__':
    sys.exit(main(sys.argv[1], sys.argv[2:]))
