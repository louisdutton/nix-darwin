"""Do not start Kodi without a working audio backend (its pre-init loop is unsafe)."""
import subprocess
import sys
import time


def wait_for_audio(probe, seconds=20):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            break
        try:
            result = subprocess.run(
                [probe, 'info', '0'], stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL, timeout=min(1, remaining),
                check=False,
            )
            if result.returncode == 0:
                return True
        except subprocess.TimeoutExpired:
            pass
        except OSError:
            return False
        time.sleep(min(0.25, max(0, deadline - time.monotonic())))
    return False


if __name__ == '__main__':
    if not wait_for_audio(sys.argv[1]):
        print('Kodi not started: PipeWire did not become ready within 20 seconds. '
              'Check systemctl --user status pipewire wireplumber.', file=sys.stderr)
        sys.exit(1)
