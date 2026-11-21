import json
from pathlib import Path
import sys

THEMES = Path(__file__).resolve().parents[1] / 'themes'
sys.path.insert(0, str(THEMES))
import wallpapers

def current(config, palette):
    chosen = wallpapers.effective(config, palette)
    if chosen:
        return chosen
    image = 'Mechanicus_light.png' if wallpapers.palette_mode(palette) == 'light' else 'Mechanicus_Dark.png'
    return str(THEMES / 'wallpapers' / image)

def main():
    command, palette, *args = sys.argv[1:]
    config = wallpapers.read_config(palette)
    if command == 'path':
        print(current(config, palette))
        return
    if command == 'config':
        print(json.dumps(dict(config, current=current(config, palette))))
        return
    if command == 'directory' and len(args) == 1:
        config['directory'] = str(wallpapers.local_path(args[0], directory=True))
    elif command == 'mode' and len(args) == 1 and args[0] in {'shared', 'variant'}:
        previous = wallpapers.effective(config, palette)
        config['mode'] = args[0]
        config['shared'] = config['shared'] if wallpapers.existing(config['shared']) else previous
        if args[0] == 'variant':
            for slot in ('light', 'dark'):
                if not wallpapers.existing(config[slot]):
                    config[slot] = config['shared']
    elif command == 'set' and len(args) == 2:
        slot = 'shared' if args[0] == 'shared' else wallpapers.palette_mode(args[0])
        path = wallpapers.local_path(args[1])
        config[slot] = str(path)
        if not config['directory']:
            config['directory'] = str(path.parent)
    else:
        raise ValueError('Unknown wallpaper setting')
    wallpapers.save(config)
    print(json.dumps({'ok': True}))

if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError) as error:
        print(json.dumps({'error': str(error)}))
        sys.exit(1)
