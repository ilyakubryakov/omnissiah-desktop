import fcntl
import json
import os
import re
import subprocess
import time
from pathlib import Path

LEVEL = 0.2
STALE = 180
STATE = Path(os.environ.get('XDG_RUNTIME_DIR') or f'/run/user/{os.getuid()}') / 'oninix-duck.json'
QUIET = STATE.with_name('oninix-duck-quiet')

def _run(*command):
    try:
        return subprocess.run(command, capture_output=True, text=True, timeout=5).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ''

def _sinks():
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
    try:
        temporary = QUIET.with_suffix('.tmp')
        temporary.write_text(f'{time.time() + 2:.3f} {value:.3f}\n')
        temporary.replace(QUIET)
    except OSError:
        pass
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
    sinks = _sinks()
    saved, state['saved'] = state['saved'], {}
    restored = 0
    for node, record in saved.items():
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
    def change(state):
        state['holders'].pop(holder, None)
        if state['holders'] or not state['saved']:
            return 0
        return _restore_saved(state)
    return _locked(change)

def tidy():
    if not STATE.exists():
        return 0
    def change(state):
        if state['holders'] or not state['saved']:
            return 0
        return _restore_saved(state)
    return _locked(change)
