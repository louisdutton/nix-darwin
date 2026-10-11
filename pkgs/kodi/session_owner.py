"""Own the Kodi service; session death must not orphan its shell descendants."""
import ctypes
import fcntl
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time
import uuid


def main(systemd_run, systemctl, guardian, command):
    def terminate(signum, frame):
        raise SystemExit(128 + signum)
    signal.signal(signal.SIGTERM, terminate)
    signal.signal(signal.SIGHUP, terminate)
    parent = os.getppid()
    # SDDM's session shell disappearing must also end this owner.
    if ctypes.CDLL(None, use_errno=True).prctl(1, signal.SIGTERM, 0, 0, 0):
        raise OSError('Could not register Kodi session parent-death signal')
    if os.getppid() != parent:
        return 1
    # Home Manager exports KODI_DATA for the normal profile too. Only a
    # different profile is a preview requiring its own unit and limits.
    private = 'KODI_DATA' in os.environ and Path(os.environ['KODI_DATA']).expanduser().resolve() != (Path.home() / '.kodi').resolve()
    unit = ('kodi-private-' + uuid.uuid4().hex if private else 'theatre-kodi') + '.service'
    lock = None
    if not private:
        runtime = Path(os.environ['XDG_RUNTIME_DIR'])
        lock = (runtime / 'theatre-kodi.lock').open('a+')
        for _ in range(50):
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                time.sleep(0.1)
        else:
            print('Kodi is already running in this session.', file=sys.stderr)
            return 1
        # After a forced owner death, the lock releases before systemd has
        # finished killing the old service. Don't race its remaining sockets.
        for _ in range(50):
            state = subprocess.run([systemctl, '--user', 'show', unit,
                                    '--property=ActiveState', '--value'],
                                   capture_output=True, text=True, timeout=3).stdout.strip()
            if state not in ('active', 'activating', 'deactivating'):
                break
            time.sleep(0.1)
        else:
            print('Previous Kodi service has not stopped; refusing a duplicate.', file=sys.stderr)
            return 1
    argv = [systemd_run, '--user', '--quiet', '--collect', '--wait', '--pipe',
            '--service-type=exec', '--expand-environment=no', '--unit=' + unit,
            '--property=KillMode=control-group', '--property=TimeoutStopSec=3s',
            '--property=SendSIGKILL=yes', '--property=Delegate=no',
            '--working-directory=' + os.getcwd()]
    if private:
        argv.extend(['--property=CPUQuota=200%', '--property=MemoryMax=2G'])
    argv.extend('--setenv=' + name for name in os.environ
                if re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', name))
    identity = ['SteamLaunch', 'AppId=1000000001', '--'] if os.environ.get('THEATRE_COMPOSITOR') == 'gamescope' else []
    argv.extend(['--', sys.executable, guardian, str(os.getpid()), *identity, *command])
    process = None
    try:
        process = subprocess.Popen(argv)
        return process.wait()
    finally:
        if process is not None:
            # Stop the actual cgroup, not just the systemd-run client.
            subprocess.run([systemctl, '--user', 'stop', unit],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        if lock is not None:
            lock.close()


if __name__ == '__main__':
    sys.exit(main(*sys.argv[1:4], sys.argv[4:]))
