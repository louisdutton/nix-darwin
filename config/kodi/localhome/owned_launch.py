"""One transient service per launch, including all child processes."""
import os
from pathlib import Path
import re
import subprocess
import uuid


class OwnedLaunch:
    def __init__(self, game, tools):
        self.tools = tools
        self.unit = 'kodi-game-' + uuid.uuid4().hex + '.service'
        directory = Path.home() / '.local/state/kodi-games'
        directory.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.log_path = directory / (self.unit + '.log')
        environment = game.get('environment', dict(os.environ))
        argv = [tools['systemd-run'], '--user', '--quiet', '--collect', '--wait', '--pipe',
                '--service-type=exec', '--expand-environment=no', '--unit=' + self.unit,
                '--property=KillMode=control-group', '--property=TimeoutStopSec=3s',
                '--property=SendSIGKILL=yes', '--property=Delegate=no',
                '--working-directory=' + game.get('cwd', str(Path.home()))]
        # Pass names, not credential values, on the command line. systemd-run
        # reads their values from its own environment and sends them over D-Bus.
        argv.extend('--setenv=' + name for name in environment if re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', name))
        identity = ['SteamLaunch', 'AppId=1000000002', '--'] if environment.get('THEATRE_COMPOSITOR') == 'gamescope' else []
        argv.extend(['--', tools['python'], str(Path(__file__).with_name('launch_guardian.py')),
                     str(os.getpid()), *identity, *game['command']])
        with self.log_path.open('xb') as log:
            self.log_path.chmod(0o600)
            self.process = subprocess.Popen(argv, env=environment, stdin=subprocess.DEVNULL,
                                            stdout=log, stderr=subprocess.STDOUT, start_new_session=True)

    def poll(self):
        return self.process.poll()

    def stop(self):
        # Wait for the start job to settle; otherwise a cancel could race the
        # D-Bus request and stop an as-yet nonexistent unit.
        if self.process.poll() is None:
            for _ in range(50):
                result = subprocess.run([self.tools['systemctl'], '--user', 'show', self.unit,
                                         '--property=LoadState', '--value'], capture_output=True, text=True, timeout=3)
                if result.stdout.strip() == 'loaded' or self.process.poll() is not None:
                    break
                import time
                time.sleep(0.1)
            else:
                # Stop the submitter, then send the unit stop regardless: any
                # request already accepted by systemd is ordered before it.
                self.process.terminate()
        result = subprocess.run([self.tools['systemctl'], '--user', 'stop', self.unit],
                                capture_output=True, text=True, timeout=10)
        if result.returncode and 'not loaded' not in result.stderr and 'not found' not in result.stderr:
            raise RuntimeError('Could not terminate owned game service: ' + result.stderr.strip())
        try:
            self.process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait(timeout=3)
