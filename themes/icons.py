import configparser
from functools import lru_cache
import json
import os
from pathlib import Path
import sys
import tempfile

STATE = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'theme'
FAMILIES = {
    'papirus': ('Papirus-Light', 'Papirus-Dark'),
    'breeze': ('breeze', 'breeze-dark'),
    'tela': ('Tela-grey-light', 'Tela-grey-dark'),
    'colloid': ('Colloid-Grey-Light', 'Colloid-Grey-Dark'),
    'fluent': ('Fluent-grey-light', 'Fluent-grey-dark'),
}
DATA = list(dict.fromkeys([Path(os.environ.get('XDG_DATA_HOME', str(Path.home() / '.local/share'))),
    *map(Path, os.environ.get('XDG_DATA_DIRS', '/usr/local/share:/usr/share').split(':')),
    Path('/var/lib/flatpak/exports/share')]))
ROOTS = [Path.home() / '.icons', *(d / 'icons' for d in DATA)]

def family():
    try:
        value = (STATE / 'icons.conf').read_text().strip()
    except OSError:
        value = 'papirus'
    return value if value in FAMILIES else 'papirus'

def variant(name, dark):
    return FAMILIES[name][int(dark)]

def select(name):
    if name not in FAMILIES:
        raise ValueError('Unknown icon family')
    STATE.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix='.icons-', dir=STATE)
    with os.fdopen(fd, 'w') as stream:
        stream.write(name + '\n')
    os.replace(tmp, STATE / 'icons.conf')

@lru_cache(maxsize=None)
def theme_dirs(theme):
    dirs, inherited = [], []
    for root in ROOTS:
        conf = configparser.ConfigParser(interpolation=None, strict=False)
        try:
            conf.read(root / theme / 'index.theme')
            header = conf['Icon Theme']
        except (OSError, KeyError, configparser.Error):
            continue
        inherited += header.get('Inherits', '').split(',')
        for sub in (header.get('Directories', '') + ',' + header.get('ScaledDirectories', '')).split(','):
            if not sub or sub not in conf or '..' in Path(sub).parts or Path(sub).is_absolute():
                continue
            spec = conf[sub]
            size = spec.getint('Size', 48) * spec.getint('Scale', 1)

            score = 0 if spec.get('Type') == 'Scalable' else abs(size - 48) + 1
            dirs.append((score, root / theme / sub))
    return [p for _, p in sorted(dirs, key=lambda x: x[0])], list(dict.fromkeys(i for i in inherited if i))

@lru_cache(maxsize=None)
def lookup(name, theme, seen=()):
    if not name or theme in seen:
        return ''
    if name.startswith('/'):
        return Path(name).as_uri() if Path(name).is_file() else ''
    if '/' in name or name in {'.', '..'}:
        return ''
    dirs, inherited = theme_dirs(theme)
    filenames = [name] if Path(name).suffix in {'.svg', '.png', '.xpm'} else [name + s for s in ('.svg', '.png', '.xpm')]
    for directory in dirs:
        for filename in filenames:
            target = directory / filename
            if target.is_file():
                return target.as_uri()
    for parent in inherited:
        result = lookup(name, parent, (*seen, theme))
        if result:
            return result
    return ''

def resolve(name, theme):
    for fallback in (theme, 'hicolor'):
        result = lookup(name, fallback)
        if result:
            return result
    for data in DATA:
        for filename in (name, name + '.svg', name + '.png', name + '.xpm'):
            if '/' not in filename and (data / 'pixmaps' / filename).is_file():
                return (data / 'pixmaps' / filename).as_uri()
    return ''

def catalog(names):
    try:
        active = (STATE / 'icon-theme').read_text().strip()
    except OSError:
        active = 'Papirus-Dark'
    palette = ''
    dark = 'dark' in active.lower() or not (STATE / 'name').exists()

    try:
        import tomllib
        palette = (STATE / 'name').read_text().strip()
        dark = tomllib.loads((Path(__file__).parent / palette / 'colors.toml').read_text())['mode'] == 'dark'
    except (OSError, KeyError, ValueError):
        pass
    fallback = resolve('application-x-executable', active)
    def preview_theme(key):
        base = variant(key, dark)
        custom = base + '-' + palette
        return custom if key == 'papirus' and theme_dirs(custom)[0] else base
    return {'family': family(), 'active': active,
        'icons': {name: resolve(name, active) or fallback for name in set(names) if isinstance(name, str)},
        'families': [{'id': key, 'name': key.title(), 'theme': variant(key, dark),
            'available': bool(theme_dirs(variant(key, dark))[0]),
            'preview': [resolve(n, preview_theme(key)) or resolve('application-x-executable', preview_theme(key)) for n in ('folder', 'system-file-manager', 'preferences-system', 'utilities-terminal')]}
            for key in FAMILIES]}

if __name__ == '__main__':
    command, *args = sys.argv[1:]
    if command == 'select':
        select(args[0])
    elif command == 'variant':
        print(variant(family(), args[0] == 'dark'))
    elif command == 'catalog':
        print(json.dumps(catalog(json.load(sys.stdin))))
