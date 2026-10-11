"""The Kodi session owner dying makes systemd terminate every descendant."""
import os
import ctypes
import select
import subprocess
import sys


def main(owner, command):
    if command[:1] == ['SteamLaunch']:
        # Gamescope discovers native Wayland app IDs from a reaper ancestor's
        # process name and argv; this does not involve the Steam client.
        if ctypes.CDLL(None).prctl(15, b'reaper', 0, 0, 0):
            raise OSError('Could not identify the Kodi session to Gamescope')
        command = command[command.index('--') + 1:]
    descriptor = os.pidfd_open(int(owner))
    try:
        if select.select([descriptor], [], [], 0)[0]:
            return 1
        child = subprocess.Popen(command)
        while not select.select([descriptor], [], [], 0.1)[0]:
            result = child.poll()
            if result is not None:
                return result
        return 1
    finally:
        os.close(descriptor)
        # Exiting the service's main process triggers KillMode=control-group.


if __name__ == '__main__':
    sys.exit(main(sys.argv[1], sys.argv[2:]))
