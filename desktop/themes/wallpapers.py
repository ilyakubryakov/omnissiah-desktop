"""Wallpaper preferences shared by the theme CLI and Appearance panel."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import tomllib
from urllib.parse import unquote, urlsplit
import zlib

REPO = Path(__file__).resolve().parent.parent
STATE = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'theme'
CONFIG = STATE / 'wallpapers.json'
EXTENSIONS = {'.png', '.jpg', '.jpeg', '.webp'}
EMBLEM = REPO / 'dotfiles/.config/fastfetch/mechanicus.ans'
FALLBACK = Path(os.environ.get('XDG_CACHE_HOME', str(Path.home() / '.cache'))) / 'station/fallback-wallpaper'
ANSI = ['dark_background', 'red', 'green', 'yellow', 'blue', 'magenta', 'cyan', 'white',
        'muted', 'bright_red', 'bright_green', 'bright_yellow', 'bright_blue',
        'bright_magenta', 'bright_cyan', 'bright_white']


def palette_mode(palette):
    if palette in {'light', 'dark'}:
        return palette
    if palette not in {p.parent.name for p in (REPO / 'themes').glob('*/colors.toml')}:
        raise ValueError('Unknown palette')
    return tomllib.loads((REPO / 'themes' / palette / 'colors.toml').read_text())['mode']


def existing(value):
    return bool(value) and Path(value).is_file()


def read_config(palette):
    result = dict(mode='shared', directory='', shared='', light='', dark='')
    if CONFIG.exists():
        try:
            saved = json.loads(CONFIG.read_text())
            if not isinstance(saved, dict) or any(not isinstance(v, str) for v in saved.values()):
                raise ValueError()
            result.update({k: v for k, v in saved.items() if k in result})
            if result['mode'] not in {'shared', 'variant'}:
                raise ValueError()
        except (ValueError, OSError):
            raise ValueError('Wallpaper settings could not be read') from None
        return result

    # Migrate explicit choices and the displayed image, never palette defaults.
    # The lock screen link may point at a repo default or the generated emblem; neither is a choice.
    current = Path.home() / '.cache/hyprlock-wall'
    if current.is_file() and not current.resolve().is_relative_to(REPO) \
            and not current.resolve().is_relative_to(FALLBACK.resolve()):
        result['shared'] = str(current.resolve())
    overrides = STATE / 'wallpapers'
    for source in sorted(overrides.glob('*')) if overrides.is_dir() else []:
        try:
            mode = palette_mode(source.name)
            path = source.read_text().strip()
            if existing(path):
                if not result[mode] or source.name == palette:
                    result[mode] = path
                if source.name == palette and not result['shared']:
                    result['shared'] = path
        except (ValueError, OSError):
            continue
    if result['light'] or result['dark']:
        result['mode'] = 'variant'
    selected = effective(result, palette)
    if selected:
        result['directory'] = str(Path(selected).parent)
    return result


def effective(config, palette):
    slot = palette_mode(palette) if config['mode'] == 'variant' else 'shared'
    for value in (config[slot], config['shared']):
        if existing(value):
            return value
    return ''


def emblem_pixels(text):
    # Half-block art: each cell is two square pixels; None is the terminal background.
    rows = []
    for line in text.rstrip('\n').split('\n'):
        top, bottom = [], []
        for codes, char in re.findall(r'\x1b\[([0-9;]*)m(.)', line):
            fg = bg = None
            for code in map(int, filter(None, codes.split(';'))):
                if 30 <= code <= 37 or 90 <= code <= 97:
                    fg = code % 10 + (8 if code >= 90 else 0)
                elif 40 <= code <= 47 or 100 <= code <= 107:
                    bg = code % 10 + (8 if code >= 100 else 0)
            top.append(fg if char == '▀' else bg)
            bottom.append(fg if char == '▄' else bg)
        rows += [top, bottom]
    return rows


def png(path, width, height, rows):
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
    raw = b''.join(b'\0' + row for row in rows)
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
                     + chunk(b'IDAT', zlib.compress(raw, 6)) + chunk(b'IEND', b''))


def fallback(palette):
    # Nothing chosen or the image is unavailable: the ANSI emblem in the palette's terminal colors.
    colors = tomllib.loads((REPO / 'themes' / palette / 'colors.toml').read_text())
    art = EMBLEM.read_text(encoding='utf-8')
    width, height, scale = 5120, 2160, 20
    key = hashlib.sha256(f'v1:{width}x{height}:{scale}:{colors}:{art}'.encode()).hexdigest()[:16]
    target = FALLBACK / f'{palette}-{key}.png'
    if target.is_file():
        return target
    rgb = [bytes.fromhex(colors[name].lstrip('#')) for name in ANSI]
    background = bytes.fromhex(colors['background'].lstrip('#'))
    pixels = emblem_pixels(art)
    left = (width - len(pixels[0]) * scale) // 2
    top = (height - len(pixels) * scale) // 2
    blank = background * width
    lines = [blank] * top
    for row in pixels:
        line = background * left + b''.join((background if c is None else rgb[c]) * scale for c in row)
        lines += [line + background * (width - len(line) // 3)] * scale
    lines += [blank] * (height - len(lines))
    FALLBACK.mkdir(parents=True, exist_ok=True)
    for old in FALLBACK.glob(palette + '-*.png'):
        old.unlink(missing_ok=True)
    fd, name = tempfile.mkstemp(suffix='.png', prefix='.emblem-', dir=FALLBACK)
    os.close(fd)
    try:
        png(Path(name), width, height, lines)
        os.chmod(name, 0o644)
        os.replace(name, target)
    finally:
        Path(name).unlink(missing_ok=True)
    return target


def local_path(value, directory=False):
    if value.startswith('file:'):
        url = urlsplit(value)
        if url.netloc not in {'', 'localhost'} or url.query or url.fragment:
            raise ValueError('Choose a local folder' if directory else 'Choose a local image')
        value = unquote(url.path)
    elif '://' in value:
        raise ValueError('Choose a local folder' if directory else 'Choose a local image')
    if not value or any(c in value for c in '\n\r\0'):
        raise ValueError('Choose an existing path without line breaks')
    path = Path(value).expanduser().resolve()
    if directory:
        if not path.is_dir() or not os.access(path, os.R_OK | os.X_OK):
            raise ValueError('Choose an existing, readable folder')
    elif (not path.is_file() or not os.access(path, os.R_OK)
          or path.suffix.lower() not in EXTENSIONS or ',' in str(path)):
        raise ValueError('Choose a readable PNG, JPEG or WebP without commas in its path')
    return path


def apply(path):
    path = local_path(path)
    if os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'):
        result = subprocess.run(['hyprctl', 'hyprpaper', 'wallpaper', ',' + str(path)],
                                capture_output=True, text=True, timeout=12)
        # hyprpaper 0.8 returns an empty successful reply; older releases say ok.
        if result.returncode or result.stdout.strip().lower() not in {'', 'ok'}:
            raise RuntimeError('The wallpaper service could not apply this image')
        link = Path.home() / '.cache/hyprlock-wall'
        link.parent.mkdir(parents=True, exist_ok=True)
        temporary = link.with_name('.hyprlock-wall-' + str(os.getpid()))
        try:
            temporary.symlink_to(path)
            temporary.replace(link)
        finally:
            temporary.unlink(missing_ok=True)
    elif shutil.which('plasma-apply-wallpaperimage'):
        subprocess.run(['plasma-apply-wallpaperimage', str(path)], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=12)


def save(config):
    STATE.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix='.wallpapers-', dir=STATE)
    try:
        with os.fdopen(fd, 'w') as stream:
            json.dump(config, stream, ensure_ascii=False)
            stream.write('\n')
        os.replace(name, CONFIG)
    finally:
        Path(name).unlink(missing_ok=True)


def main():
    command, palette, *args = sys.argv[1:]
    config = read_config(palette)
    if command == 'config' and not args:
        print(json.dumps(dict(config, current=effective(config, palette))))
        return
    if command == 'path' and not args:
        print(effective(config, palette) or ('' if palette in {'light', 'dark'} else fallback(palette)))
        return
    if command == 'apply' and len(args) == 1:
        apply(args[0])
        return
    previous = effective(config, palette)
    if command == 'directory' and len(args) == 1:
        config['directory'] = str(local_path(args[0], directory=True))
    elif command == 'mode' and len(args) == 1 and args[0] in {'shared', 'variant'}:
        config['mode'] = args[0]
        if not existing(config['shared']):
            config['shared'] = previous
        if args[0] == 'variant':
            for slot in ('light', 'dark'):
                if not existing(config[slot]):
                    config[slot] = config['shared']
    elif command == 'set' and len(args) == 2:
        slot, value = args
        if slot != 'shared':
            slot = palette_mode(slot)
        path = str(local_path(value))
        config[slot] = path
        if not config['directory']:
            config['directory'] = str(Path(path).parent)
    else:
        raise ValueError('Unknown wallpaper setting')
    selected = effective(config, palette)
    if selected and (selected != previous or command == 'set' and config.get(slot) == selected):
        apply(selected)
    save(config)
    print(json.dumps({'ok': True}))


if __name__ == '__main__':
    os.umask(0o077)
    try:
        main()
    except Exception as error:
        message = str(error) if isinstance(error, (ValueError, RuntimeError)) else 'Wallpaper service unavailable'
        print(json.dumps({'error': message}))
        raise SystemExit(1)
