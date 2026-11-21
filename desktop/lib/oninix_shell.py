from contextlib import contextmanager
from copy import deepcopy
import fcntl
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time

GROUPS = ('launchers', 'workspaces', 'status', 'media', 'window', 'metrics')
TILES = ('network', 'bluetooth', 'dnd', 'awake', 'nightlight', 'microphone', 'output',
         'mode:work', 'mode:call', 'mode:game', 'mode:music', 'mode:normal')
PAGES = ('quick', 'audio', 'network', 'displays', 'devices', 'power', 'session', 'system',
         'clipboard', 'calendars', 'overview', 'themes', 'panels', 'apps', 'login', 'modes')
LAYOUT = {'top': list(GROUPS[:3]), 'bottom': list(GROUPS[3:]), 'hidden': []}
ITEMS = {'launchers': ['applications', 'notebook'],
         'status': ['tray', 'network', 'battery', 'recording', 'awake', 'capture',
                    'microphone', 'notifications', 'volume', 'clock', 'controls']}
APP_ITEM = re.compile(r'app:[\w.+-]{1,200}')
DEFAULT = {'version': 1, 'favorites': list(TILES[:6]),
           'layouts': {'primary': deepcopy(LAYOUT), 'secondary': deepcopy(LAYOUT)},
           'items': deepcopy(ITEMS),
           'ui': {'last': 'quick', 'scroll': {}}}
LOOK_FILES = ('name', 'shell.json', 'panels.json', 'desktop.conf', 'icons.conf', 'launchers.json', 'schedule.conf')

def state():
    return Path(os.environ.get('XDG_STATE_HOME', Path.home() / '.local/state'))

def read(path, default):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return deepcopy(default)

def atomic(path, data, *, mode=None):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix='.' + path.name, dir=path.parent)
    try:
        with os.fdopen(fd, 'wb' if isinstance(data, bytes) else 'w') as stream:
            stream.write(data)
            if mode is not None:
                os.fchmod(stream.fileno(), mode)
        os.replace(tmp, path)
    finally:
        Path(tmp).unlink(missing_ok=True)

def write(path, value):
    atomic(path, json.dumps(value, ensure_ascii=False, indent=2) + '\n')

@contextmanager
def change_lock():
    folder = state() / 'oninix'
    folder.mkdir(parents=True, exist_ok=True)
    with (folder / 'shell.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield

def validate_layout(value):
    if not isinstance(value, dict) or set(value) != {'top', 'bottom', 'hidden'}:
        raise ValueError('A panel layout needs top, bottom and hidden groups')
    if not all(isinstance(items, list) and all(isinstance(i, str) for i in items) for items in value.values()):
        raise ValueError('Invalid panel groups')
    items = value['top'] + value['bottom'] + value['hidden']
    if sorted(items) != sorted(GROUPS) or 'status' in value['hidden']:
        raise ValueError('Keep every group once and keep the Control Station group visible')
    return value

def validate_items(value):
    if not isinstance(value, dict) or set(value) != set(ITEMS):
        raise ValueError('Panel icons need the launchers and status groups')
    if not all(isinstance(items, list) and all(isinstance(i, str) for i in items) for items in value.values()):
        raise ValueError('Invalid panel icons')
    tokens = value['launchers'] + value['status']
    applets = [t for t in tokens if not APP_ITEM.fullmatch(t)]
    if len(tokens) > 120 or len(set(tokens)) != len(tokens) or sorted(applets) != sorted(ITEMS['launchers'] + ITEMS['status']):
        raise ValueError('Keep every panel icon once')
    if 'controls' not in value['status']:
        raise ValueError('Keep Control Station in the status group')
    return value

def preferences():
    value = read(state() / 'theme/control-center.json', DEFAULT)
    result = deepcopy(DEFAULT)
    if not isinstance(value, dict):
        return result
    favorites = value.get('favorites')
    if isinstance(favorites, list) and all(isinstance(i, str) and i in TILES for i in favorites) and len(set(favorites)) == len(favorites):
        result['favorites'] = favorites
    for role in ('primary', 'secondary'):
        try:
            result['layouts'][role] = validate_layout(value.get('layouts', {})[role])
        except (ValueError, KeyError, TypeError):
            pass
    try:
        result['items'] = validate_items(value.get('items'))
    except ValueError:
        pass
    ui = value.get('ui', {})
    if isinstance(ui, dict):
        if ui.get('last') in PAGES:
            result['ui']['last'] = ui['last']
        scroll = ui.get('scroll', {})
        if isinstance(scroll, dict):
            result['ui']['scroll'] = {k: v for k, v in scroll.items() if k in PAGES
                                      and type(v) in (int, float) and 0 <= v <= 1}
    return result

def save_preferences(value):
    write(state() / 'theme/control-center.json', value)

def look_path(name):
    if name == 'schedule.conf':
        return Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')) / 'theme-schedule.conf'
    return state() / 'theme' / name

def snapshot():
    files = {}
    for name in LOOK_FILES:
        path = look_path(name)
        files[name] = path.read_text() if path.is_file() else None
    prefs = preferences()
    return {'files': files, 'layouts': prefs['layouts'], 'items': prefs['items']}

def remember(before, label='Appearance changed'):
    if before != snapshot():
        write(state() / 'oninix/appearance-undo.json', {'snapshot': before, 'label': label, 'at': time.time()})

def apply_snapshot(value):
    if not isinstance(value, dict):
        raise ValueError('Invalid appearance preset')
    before = snapshot()
    files = value.get('files', {})
    if not isinstance(files, dict) or set(files) != set(LOOK_FILES):
        raise ValueError('Invalid appearance preset')
    for name, text in files.items():
        if text is not None and (not isinstance(text, str) or len(text) > 65536):
            raise ValueError('Appearance preset is too large')
        if text is not None and name.endswith('.json'):
            json.loads(text)
    palette = (files.get('name') or '').strip()
    if palette and not re.fullmatch(r'[a-z0-9-]{1,48}', palette):
        raise ValueError('Invalid palette name')
    layouts = {role: validate_layout(value.get('layouts', {})[role]) for role in ('primary', 'secondary')}
    items = validate_items(value['items']) if 'items' in value else None
    for name, text in files.items():
        path = look_path(name)
        if text is None:
            path.unlink(missing_ok=True)
        else:
            atomic(path, text)
    prefs = preferences()
    prefs['layouts'] = layouts
    if items is not None:
        prefs['items'] = items
    save_preferences(prefs)
    if files != before['files']:
        subprocess.run(['oninix-theme'] + (['set', palette] if palette else []), check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=120)
    if files.get('desktop.conf') != before['files'].get('desktop.conf'):
        subprocess.run(['hyprctl', 'reload'], check=True, stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL, timeout=10)

def data():
    looks = read(state() / 'theme/looks.json', {})
    undo = read(state() / 'oninix/appearance-undo.json', {})
    if not isinstance(undo, dict):
        undo = {}
    return {'prefs': preferences(), 'looks': sorted(looks) if isinstance(looks, dict) else [],
            'undo': bool(undo.get('snapshot')), 'undoLabel': undo.get('label', ''),
            'devices': read(state() / 'oninix/work-mode-devices.json', {})}

def dispatch(args):
    command = args[0] if args else 'data'
    if command == 'data' and len(args) <= 1:
        return data()
    if len(args) != 2:
        raise ValueError('Invalid shell settings action')
    value = json.loads(args[1])
    with change_lock():
        prefs = preferences()
        if command == 'favorites':
            if not isinstance(value, list) or any(i not in TILES for i in value) or len(set(value)) != len(value):
                raise ValueError('Invalid favorite actions')
            prefs['favorites'] = value
            save_preferences(prefs)
        elif command == 'ui':
            if not isinstance(value, dict) or value.get('last') not in PAGES:
                raise ValueError('Invalid settings page')
            prefs['ui']['last'] = value['last']
            for key, pos in value.get('scroll', {}).items():
                if key not in PAGES or type(pos) not in (float, int) or not 0 <= pos <= 1:
                    raise ValueError('Invalid scroll position')
                prefs['ui']['scroll'][key] = pos
            save_preferences(prefs)
        elif command == 'layout':
            if not isinstance(value, dict) or value.get('role') not in ('primary', 'secondary'):
                raise ValueError('Invalid screen role')
            before = snapshot()
            prefs['layouts'][value['role']] = validate_layout(value.get('layout'))
            save_preferences(prefs)
            remember(before, 'Panel layout changed')
        elif command == 'items':
            before = snapshot()
            prefs['items'] = validate_items(value)
            save_preferences(prefs)
            remember(before, 'Panel icons moved')
        elif command == 'devices':
            if not isinstance(value, dict) or value.get('mode') not in ('work', 'call', 'game', 'music'):
                raise ValueError('Invalid work mode')
            devices = read(state() / 'oninix/work-mode-devices.json', {})
            if not isinstance(devices, dict):
                devices = {}
            selected = {key: value.get(key, '') for key in ('sink', 'source')}
            if any(not isinstance(v, str) or len(v) > 300 or any(ord(c) < 32 for c in v) for v in selected.values()):
                raise ValueError('Invalid audio device')
            devices[value['mode']] = selected
            write(state() / 'oninix/work-mode-devices.json', devices)
        elif command in ('look-save', 'look-apply', 'look-delete'):
            if not isinstance(value, str) or not 1 <= len(value.strip()) <= 40 or any(ord(c) < 32 for c in value):
                raise ValueError('Use a preset name of 1 to 40 characters')
            value = value.strip()
            looks = read(state() / 'theme/looks.json', {})
            if not isinstance(looks, dict):
                looks = {}
            if command == 'look-save':
                if value not in looks and len(looks) >= 12:
                    raise ValueError('Keep up to twelve appearance presets')
                looks[value] = snapshot()
            elif command == 'look-delete':
                looks.pop(value, None)
            else:
                if value not in looks:
                    raise ValueError('Appearance preset not found')
                before = snapshot()
                try:
                    apply_snapshot(looks[value])
                except Exception:
                    apply_snapshot(before)
                    raise
                remember(before, 'Applied ' + value)
            write(state() / 'theme/looks.json', looks)
        elif command == 'undo':
            undo = read(state() / 'oninix/appearance-undo.json', {})
            if not undo.get('snapshot'):
                raise ValueError('No appearance change to undo')
            before = snapshot()
            try:
                apply_snapshot(undo['snapshot'])
            except Exception:
                apply_snapshot(before)
                raise
            (state() / 'oninix/appearance-undo.json').unlink(missing_ok=True)
        else:
            raise ValueError('Unknown shell settings action')
    return data()
