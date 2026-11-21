import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unicodedata
from pathlib import Path


def character_width(char):
    if unicodedata.combining(char):
        return 0
    return 2 if unicodedata.east_asian_width(char) in ('W', 'F') else 1


def clipped(text, limit):
    parts = []
    used = 0
    for token in re.findall(r'\x1b\[[0-?]*[ -/]*[@-~]|[^\x00-\x1f\x7f]', text):
        if token.startswith('\x1b'):
            if token.endswith('m'):
                parts.append((token, 0))
            elif token.endswith('G') and token[2:-1].isdigit():
                count = max(0, min(limit, int(token[2:-1]) - 1) - used)
                parts.extend([(' ', 1)] * count)
                used += count
            continue
        size = character_width(token)
        if used + size > limit:
            while used >= limit and parts:
                used -= parts.pop()[1]
            parts.append(('…', 1))
            break
        parts.append((token, size))
        used += size
    return ''.join(token for token, _ in parts) + '\x1b[0m'


def main():
    binary, config_path, image, *args = sys.argv[1:]
    config_home = Path(os.getenv('XDG_CONFIG_HOME') or Path.home() / '.config')
    user_config = config_home / 'fastfetch' / 'config.jsonc'
    legacy_config = Path.home() / '.fastfetch' / 'config.jsonc'
    if args or not sys.stdout.isatty() or user_config.is_file() or legacy_config.is_file():
        os.execv(binary, [binary, *args])

    config = json.loads(Path(config_path).read_text())
    columns, rows = shutil.get_terminal_size()
    use_image = (os.environ.get('TERM') == 'xterm-kitty' or os.environ.get('KITTY_WINDOW_ID'))
    use_image = use_image and not (os.environ.get('TMUX') or os.environ.get('STY'))
    image_width = 0
    position = 'left'
    if use_image and columns >= 96 and rows >= 22:
        image_width = min(42, columns // 3, (rows - 6) * 2)
    elif use_image and columns >= 54 and rows >= 30:
        image_width = min(24, (rows - 18) * 2)
        position = 'top'
    logo = {'type': 'none'}
    if image_width:
        logo = {'type': 'kitty', 'source': image, 'width': image_width,
                'position': position, 'padding': {'right': 3, 'bottom': 1}}

    if columns < 90 or rows < 30:
        omitted = {'board', 'shell', 'display', 'localip', 'custom', 'break'}
        if columns < 54 or rows < 22:
            omitted.update({'kernel', 'terminal', 'wm', 'disk'})
        config['modules'] = [
            module for module in config['modules']
            if (module if isinstance(module, str) else module['type']) not in omitted
        ]

    parent = Path(f'/proc/{os.getppid()}/exe')
    shell = parent.resolve().name if parent.exists() else Path(os.environ.get('SHELL', '')).name
    for module in config['modules']:
        if isinstance(module, dict) and module['type'] == 'shell':
            module.update(type='custom', format=shell.replace('{', '{{'))

    width = max(1, columns - (image_width + 3 if image_width and position == 'left' else 0) - 1)
    config['display']['key']['width'] = 12 if width >= 44 else 8 if width >= 24 else 0
    if width < 24:
        config['display']['key']['type'] = 'none'
    config['logo'] = {'type': 'none'}
    config['display'].update(pipe=False, hideCursor=False, disableLinewrap=False)
    with tempfile.TemporaryDirectory(prefix='oninix-fastfetch-') as temp:
        config_file = Path(temp) / 'config.json'
        config_file.write_text(json.dumps(config))
        command = [binary, '--config', str(config_file)]
        result = subprocess.run(command, capture_output=True, text=True, timeout=8)
        if result.returncode:
            sys.stderr.write(result.stderr)
            return result.returncode
        config['logo'] = logo
        config['modules'] = [
            {'type': 'custom', 'format': clipped(line, width).replace('{', '{{')}
            for line in result.stdout.splitlines()
        ]
        config_file.write_text(json.dumps(config))
        return subprocess.call(command)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except subprocess.TimeoutExpired:
        sys.exit('fastfetch: hardware detection timed out')
    except KeyboardInterrupt:
        sys.exit(130)
