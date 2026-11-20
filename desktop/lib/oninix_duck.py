"""Turn the station's playback down while you speak to the machine, and back up after.

Owner decision 2026-11-09: music is ducked, not paused, while dictation (Right
Alt) and the machine spirit by Right Ctrl listen. Holders may overlap, so the volumes are
saved once, by the first holder, and restored when the last one lets go (the
desk Voice PE satellite was one until the owner switched it off, 2026-11-10). State: one small JSON in
the runtime directory, guarded by a file lock across processes.

The default sink is ducked, not the playback streams (2026-11-18): WirePlumber
remembers a stream's volume per application, so a stream that closed while
ducked (YouTube Shorts recreate theirs) came back quiet and was never restored,
compounding to 0.2, 0.04 and so on. The sink outlives the streams.
"""
import fcntl
import json
import os
import re
import subprocess
import time
from pathlib import Path

LEVEL = 0.2
# A holder that crashed without restoring must not keep the music quiet for good;
# a whole Voice PE turn with its spoken answer fits well inside this.
STALE = 180
STATE = Path(os.environ.get('XDG_RUNTIME_DIR', '/run/user/%d' % os.getuid())) / 'oninix-duck.json'


def _run(*command):
    try:
        return subprocess.run(command, capture_output=True, text=True, timeout=5).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ''


def _sinks():
    """Snapshot sink identities so a restore never touches a reused node ID."""
    try:
        nodes = json.loads(_run('pw-dump') or '[]')
    except ValueError:
        return {}
    return {str(n['id']): n['info']['props'].get('object.serial') for n in nodes
            if n.get('info', {}).get('props', {}).get('media.class') == 'Audio/Sink'}


def _default_sink():
    found = re.match(r'id (\d+),', _run('wpctl', 'inspect', '@DEFAULT_AUDIO_SINK@'))
    return found[1] if found else None


def _volume(node):
    found = re.search(r'Volume:\s*([0-9.]+)', _run('wpctl', 'get-volume', str(node)))
    return float(found[1]) if found else None


def _set(node, value):
    _run('wpctl', 'set-volume', str(node), f'{value:.3f}')


def _locked(change):
    STATE.parent.mkdir(parents=True, exist_ok=True)
    with open(STATE.with_suffix('.lock'), 'w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            state = json.loads(STATE.read_text())
        except (OSError, ValueError):
            state = {}
        if not isinstance(state.get('holders'), dict):
            state['holders'] = {}
        state.setdefault('saved', {})
        now = time.time()
        state['holders'] = {h: t for h, t in state['holders'].items() if now - t < STALE}
        result = change(state)
        STATE.write_text(json.dumps(state))
        return result


def _restore_saved(state):
    """Restore only the same sink, while its volume still belongs to us."""
    sinks = _sinks()
    saved, state['saved'] = state['saved'], {}
    restored = 0
    for node, record in saved.items():
        # Legacy records have no identity: never apply them to a possibly reused ID.
        if not isinstance(record, dict) or record.get('serial') is None:
            continue
        if str(sinks.get(node)) != str(record['serial']):
            continue
        volume = _volume(node)
        if volume is not None and abs(volume - record['ducked']) <= 0.006:
            _set(node, record['volume'])
            restored += 1
    return restored


def duck(holder):
    """Turn playback down for `holder`; returns how many sinks were turned down now."""
    def change(state):
        if not state['holders'] and state['saved']:
            _restore_saved(state)
        state['holders'][holder] = time.time()
        if state['saved']:
            return 0
        node = _default_sink()
        serial = _sinks().get(node) if node else None
        volume = _volume(node) if serial is not None else None
        if volume is not None:
            state['saved'][node] = {'serial': serial, 'volume': volume, 'ducked': round(volume * LEVEL, 3)}
            _set(node, volume * LEVEL)
        return len(state['saved'])
    return _locked(change)


def restore(holder):
    """`holder` is done; the volumes come back when nobody holds the duck any more."""
    def change(state):
        state['holders'].pop(holder, None)
        if state['holders'] or not state['saved']:
            return 0
        return _restore_saved(state)
    return _locked(change)


def tidy():
    """Bring the volumes back if every holder is gone or stale (run by oninix-dictation)."""
    if not STATE.exists():
        return 0
    def change(state):
        if state['holders'] or not state['saved']:
            return 0
        return _restore_saved(state)
    return _locked(change)
