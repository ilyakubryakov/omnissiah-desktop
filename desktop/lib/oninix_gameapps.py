import json
import os
from pathlib import Path
import re
import signal
import subprocess
import time

APPS = {
    'chrome': {'exe': r'-google-chrome-[^/]+/share/google/chrome/chrome', 'launch': ['google-chrome-stable']},
    'telegram': {'exe': r'-telegram-desktop-[^/]+/bin/\.Telegram-wrapped',
                 'launch': ['Telegram'], 'tray': ['-startintray'], 'quit': ['Telegram', '-quit']},
    'thunderbird': {'exe': r'-thunderbird-[^/]+/lib/thunderbird/thunderbird', 'launch': ['thunderbird']},
    'slack': {'exe': r'-slack-[^/]+/lib/slack/slack', 'launch': ['slack']},
}
QUIT_WAIT = 20
NAMES = {'chrome': 'Chrome', 'telegram': 'Telegram', 'thunderbird': 'Thunderbird', 'slack': 'Slack'}
CHROME_STATE = Path.home() / '.config/google-chrome/Local State'
APPLICATIONS = Path.home() / '.local/share/applications'
GAP = 6

def hypr(expression):
    reply = subprocess.run(['hyprctl', 'eval', expression], check=True, capture_output=True, timeout=10).stdout
    if reply.decode().strip() != 'ok':
        raise RuntimeError('Hyprland rejected the restore plan')

def clients():
    out = subprocess.run(['hyprctl', 'clients', '-j'], check=True, capture_output=True, timeout=10).stdout
    return json.loads(out)

def main_processes():
    exes, parents = {}, {}
    uid = os.getuid()
    for entry in Path('/proc').iterdir():
        if not entry.name.isdigit():
            continue
        try:
            if entry.stat().st_uid != uid:
                continue
            exes[int(entry.name)] = os.readlink(entry / 'exe')
            parents[int(entry.name)] = int((entry / 'stat').read_text().rsplit(')', 1)[1].split()[1])
        except (OSError, ValueError, IndexError):
            continue
    found = {}
    for pid, exe in exes.items():
        if exes.get(parents[pid]) == exe:
            continue
        for key, app in APPS.items():
            if re.search(app['exe'] + '$', exe):
                found.setdefault(key, []).append(pid)
    return found

def alive(pid):
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    try:
        return Path('/proc', str(pid), 'stat').read_text().rsplit(')', 1)[1].split()[0] != 'Z'
    except (OSError, IndexError):
        return False

def quit_app(key, pids):
    app = APPS[key]
    if app.get('quit'):
        subprocess.run(app['quit'], capture_output=True, timeout=10)
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline and any(alive(p) for p in pids):
            time.sleep(0.2)
    for pid in pids:
        if alive(pid):
            try:
                os.kill(pid, signal.SIGTERM)
            except ProcessLookupError:
                pass

def progress(direction, step, state='running', done=0, total=0):
    base = os.environ.get('XDG_RUNTIME_DIR')
    if not base:
        return
    path = Path(base, 'oninix-desktop', 'game-progress.json')
    try:
        path.parent.mkdir(mode=0o700, exist_ok=True)
        tmp = path.with_suffix('.tmp')
        tmp.write_text(json.dumps({'direction': direction, 'step': step, 'state': state,
                                   'done': done, 'total': total, 'at': time.time()}))
        tmp.replace(path)
    except OSError:
        pass

def vram_used():
    try:
        out = subprocess.run(['nvidia-smi', '--query-gpu=memory.used', '--format=csv,noheader,nounits'],
                             check=True, capture_output=True, timeout=5).stdout
        return int(out.split()[0])
    except (OSError, subprocess.SubprocessError, ValueError, IndexError):
        return None

def box(c):
    x, y = c['at']
    w, h = c['size']
    return [x, y, x + w, y + h]

def tiles_of(windows):
    by_address = {w['address']: w for w in windows}
    tiles, seen = [], set()
    for w in windows:
        if w['floating'] or w['address'] in seen:
            continue
        members = [a for a in (w.get('grouped') or []) if a in by_address] or [w['address']]
        seen.update(members)
        current = min(members, key=lambda a: (bool(by_address[a].get('hidden')),
                                              by_address[a].get('focusHistoryID', 1 << 30)))
        boxes = [box(by_address[a]) for a in members]
        tiles.append({'members': members, 'current': current,
                      'box': [min(b[0] for b in boxes), min(b[1] for b in boxes),
                              max(b[2] for b in boxes), max(b[3] for b in boxes)]})
    return tiles

def split_tree(tiles):
    if len(tiles) == 1:
        return {'tile': tiles[0]}
    for axis, low, high in (('h', 0, 2), ('v', 1, 3)):
        edges = sorted({t['box'][high] for t in tiles})
        for cut in edges[:-1]:
            first = [t for t in tiles if t['box'][high] <= cut + GAP]
            second = [t for t in tiles if t['box'][low] >= cut - GAP and t not in first]
            if first and second and len(first) + len(second) == len(tiles):
                return {'dir': axis, 'a': split_tree(first), 'b': split_tree(second)}
    ordered = sorted(tiles, key=lambda t: (t['box'][0], t['box'][1]))
    return {'dir': 'h', 'a': {'tile': ordered[0]}, 'b': split_tree(ordered[1:])}

def plan(windows, closing_pids):
    closing = [w for w in windows if w['pid'] in closing_pids]
    slots, by_address = [], {}

    def slot(w):
        if w['address'] not in by_address:
            leaving = w['pid'] in closing_pids
            by_address[w['address']] = len(slots) + 1
            slots.append({'id': len(slots) + 1, 'address': None if leaving else w['address'],
                          'class': w['class'], 'title': w['title'] if leaving else '',
                          'w': w['size'][0], 'h': w['size'][1], 'fullscreen': w.get('fullscreen', 0)})
        return by_address[w['address']]

    def node(tree):
        if 'tile' in tree:
            t = tree['tile']
            return {'members': [slot(lookup[a]) for a in t['members']], 'current': slot(lookup[t['current']])}
        return {'dir': tree['dir'], 'a': node(tree['a']), 'b': node(tree['b'])}

    lookup = {w['address']: w for w in windows}
    workspaces, floating, special = [], [], []
    names = []
    for w in closing:
        name = w['workspace']['name']
        if name not in names:
            names.append(name)
    for name in names:
        here = [w for w in windows if w['workspace']['name'] == name]
        if name.startswith('special:'):
            special.extend({'slot': slot(w), 'workspace': name, 'floating': w['floating'],
                            'group': [slot(lookup[a]) for a in (w.get('grouped') or []) if a in lookup]}
                           for w in here if w['pid'] in closing_pids)
            continue
        tiles = tiles_of(here)
        if any(lookup[a]['pid'] in closing_pids for t in tiles for a in t['members']):
            workspaces.append({'name': name, 'tree': node(split_tree(tiles))})
        floating.extend({'slot': slot(w), 'workspace': name, 'x': w['at'][0], 'y': w['at'][1]}
                        for w in here if w['floating'] and w['pid'] in closing_pids)
    return {'slots': slots, 'workspaces': workspaces, 'floating': floating, 'special': special}

def lua(value):
    if value is None:
        return 'nil'
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, str):
        return json.dumps(''.join(c for c in value if ord(c) >= 32 and c not in '  '), ensure_ascii=False)
    if isinstance(value, list):
        return '{' + ','.join(lua(v) for v in value) + '}'
    if isinstance(value, dict):
        if not all(re.fullmatch(r'[a-z_]+', k) for k in value):
            raise ValueError('Invalid restore plan key')
        return '{' + ','.join(k + '=' + lua(v) for k, v in value.items()) + '}'
    raise TypeError('Unsupported restore plan value')

def close(keys=tuple(APPS)):
    running = {k: v for k, v in main_processes().items() if k in keys}
    if not running:
        return {}
    windows = clients()
    pids = {p for ps in running.values() for p in ps}
    windowed = {k for k, ps in running.items() if any(w['pid'] in ps for w in windows)}
    snapshot = {'apps': [{'key': k, 'tray': k not in windowed} for k in running],
                'plan': plan(windows, pids),
                'webapps': webapp_entries(windows, set(running.get('chrome', [])))}
    progress('on', 'Closing ' + ', '.join(NAMES[k] for k in running))
    for key, ps in running.items():
        quit_app(key, ps)
    deadline = time.monotonic() + QUIT_WAIT
    while time.monotonic() < deadline and any(alive(p) for p in pids):
        time.sleep(0.3)
    still = {k for k, ps in running.items() if any(alive(p) for p in ps)}
    snapshot['apps'] = [a for a in snapshot['apps'] if a['key'] not in still]
    snapshot['still_running'] = sorted(still)
    return snapshot

def chrome_profiles():
    try:
        profile = json.loads(CHROME_STATE.read_text()).get('profile', {})
    except (OSError, ValueError):
        return ['Default']
    known = profile.get('info_cache', {})
    names = [n for n in profile.get('last_active_profiles') or [profile.get('last_used')]
             if isinstance(n, str) and n in known and re.fullmatch(r'[A-Za-z0-9 _.-]+', n)]
    return names or ['Default']

def chrome_launches(profiles):
    return [['google-chrome-stable', '--profile-directory=' + p, '--restore-last-session'] for p in profiles]

def webapp_entries(windows, pids):
    classes = {w['class'] for w in windows if w['pid'] in pids and w['class'] != 'google-chrome'}
    entries = []
    for path in sorted(APPLICATIONS.glob('*.desktop')):
        try:
            entries.append((path, path.read_text()))
        except OSError:
            continue
    entries.sort(key=lambda e: 'X-OniNix-WebApp=true' not in e[1])
    found = []
    for path, text in entries:
        match = re.search(r'^StartupWMClass=(.+)$', text, re.M)
        if match and match.group(1).strip() in classes and re.fullmatch(r'[A-Za-z0-9._-]+\.desktop', path.name):
            found.append(path.name)
            classes.discard(match.group(1).strip())
    return found

def launch(argv):
    subprocess.Popen(['uwsm', 'app', '--'] + argv, stdin=subprocess.DEVNULL,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)

def restore(snapshot):
    apps = [a for a in snapshot.get('apps', []) if a.get('key') in APPS]
    if not apps:
        return False
    running = main_processes()
    apps = [a for a in apps if a['key'] not in running]  # Reopened by hand while gaming.
    if not apps:
        return False
    progress('off', 'Starting ' + ', '.join(NAMES[a['key']] for a in apps))
    arranging = bool(snapshot.get('plan', {}).get('slots')) and bool(os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'))
    if arranging:
        hypr('require("gamerestore").expect(' + lua(snapshot['plan']) + ')')
    chrome = False
    for app in apps:
        if app['key'] == 'chrome':
            chrome = True
            continue
        spec = APPS[app['key']]
        launch(spec['launch'] + (spec.get('tray', []) if app.get('tray') else []))
    if not chrome:
        return arranging
    first, *others = chrome_launches(chrome_profiles())
    launch(first)
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline and 'chrome' not in main_processes():
        time.sleep(0.3)
    time.sleep(1)
    for argv in others:
        launch(argv)
    for entry in snapshot.get('webapps', []):
        if re.fullmatch(r'[A-Za-z0-9._-]+\.desktop', entry) and (APPLICATIONS / entry).is_file():
            launch([entry])
    return arranging
