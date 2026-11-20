import argparse
import html
import json
import math
import os
from pathlib import Path
import re
import tempfile
import tomllib

ROOT = Path(__file__).resolve().parent
DEFAULTS_FILE = ROOT / 'ui-metrics.toml'
KEYS = {'ui_font': 'font_family', 'ui_font_size': 'font_size',
        'ui_radius_small': 'radius_small', 'ui_radius_control': 'radius_control',
        'ui_radius_card': 'radius_card', 'ui_radius_window': 'radius_window',
        'ui_space_unit': 'space_unit', 'ui_control_height': 'control_height', 'ui_focus_width': 'focus_width'}
BOUNDS = {'font_size': (8, 20), 'radius_small': (0, 24), 'radius_control': (0, 24),
          'radius_card': (0, 32), 'radius_window': (0, 24), 'space_unit': (2, 8),
          'control_height': (28, 56), 'focus_width': (1, 3)}
BEGIN, END = '/* theme:metrics-begin */', '/* theme:metrics-end */'

def defaults():
    return tomllib.loads(DEFAULTS_FILE.read_text())

def preference_defaults():
    base = defaults()
    return {'ui_geometry': 'native', **{key: str(base[token]) for key, token in KEYS.items()}}

def valid_preference(key, value):
    if key == 'ui_geometry':
        return value in ('native', 'unified')
    token = KEYS.get(key)
    if token == 'font_family':
        return isinstance(value, str) and bool(re.fullmatch(r'[\w][\w .+-]{0,79}', value))
    if token in BOUNDS and isinstance(value, str) and value.isascii() and value.isdigit():
        low, high = BOUNDS[token]
        return low <= int(value) <= high
    return False

def state_dir():
    return Path(os.environ.get('XDG_STATE_HOME', Path.home() / '.local/state')) / 'theme'

def preferences(path=None):
    result = {}
    try:
        for line in (path or state_dir() / 'desktop.conf').read_text().splitlines():
            if '=' in line:
                key, value = line.split('=', 1)
                if key in ('windows', 'density') or valid_preference(key, value):
                    result[key] = value
    except OSError:
        pass
    return result

def resolve(prefs=None):
    prefs = preferences() if prefs is None else prefs
    base = defaults()
    for key, token in KEYS.items():
        value = prefs.get(key)
        if valid_preference(key, value):
            base[token] = value if token == 'font_family' else int(value)
    raw = dict(base)
    unified = prefs.get('ui_geometry') == 'unified'
    square = prefs.get('windows', 'flat') != 'soft'
    comfortable = prefs.get('density') == 'comfortable'
    unit = base['space_unit']
    border = base['legacy']['border_width']
    minimum = math.ceil(base['font_size'] * 96 / 72 * 1.35) + 2 * unit + 2 * border
    base['control_height'] = max(base['control_height'], minimum)
    base['control_height_comfortable'] = max(raw['control_height'] + unit, minimum)
    base['height'] = base['control_height_comfortable'] if comfortable else base['control_height']
    base['window_rounding'] = 0 if square else base['radius_window']
    if unified and square:
        for name in ('radius_small', 'radius_control', 'radius_card', 'radius_panel'):
            base[name] = 0
    legacy = base.pop('legacy')
    base.update(unified=unified, space=unit * (4 if comfortable else 3), padding_x=unit * 3,
                padding_y=unit, card_padding=unit * 4, card_spacing=unit * (4 if unified and comfortable else 3),
                border_width=border, control_min_height=base['height'] - 2 * unit - 2 * border,
                row_min_height=base['height'] - 2 * unit,
                combo_radius=base['radius_control'] if unified else legacy['combo_radius'],
                row_radius=base['radius_small'] if unified else legacy['row_radius'],
                popup_radius=base['radius_card'] if unified else legacy['popup_radius'],
                slider_height=base['height'] if unified else legacy['slider_height'],
                text_px=round(15 * base['font_size'] / 11), button_text_px=round(14 * base['font_size'] / 11),
                combo_text_px=round(13 * base['font_size'] / 11), caption_text_px=round(12 * base['font_size'] / 11),
                small_font_size=max(8, base['font_size'] - 2))
    return raw, base

def atomic(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.read_text() == text:
        return
    fd, name = tempfile.mkstemp(dir=path.parent, prefix='.' + path.name)
    try:
        with os.fdopen(fd, 'w') as output:
            output.write(text)
            os.fchmod(output.fileno(), 0o644)
        os.replace(name, path)
    finally:
        Path(name).unlink(missing_ok=True)

def geometry_block(name):
    text = (ROOT / 'templates' / name).read_text()
    return text.split(BEGIN, 1)[1].split(END, 1)[0].strip() + '\n'

def render(text, raw, effective):
    values = dict(effective, radius_window=raw['radius_window'],
                  font_family_xml=html.escape(effective['font_family']),
                  mono_family_xml=html.escape(effective['mono_family']))
    def replace(match):
        key = match[1]
        if key not in values:
            raise ValueError(f'Undefined UI metric: {key}')
        return str(values[key])
    return re.sub(r'\{\{([a-z_]+)\}\}', replace, text)

def outputs(prefs):
    raw, effective = resolve(prefs)
    result = {'ui-metrics.json': json.dumps(effective, indent=2, ensure_ascii=False) + '\n'}
    for name in ('gtk', 'gtk4'):
        result[name + '-metrics.css'] = render(geometry_block(name + '.tpl'), raw, effective) if effective['unified'] else '/* Native toolkit geometry retained. */\n'
    for name, output in [('kde.tpl', 'kde-fonts.ini'), ('qt5ct.tpl', 'qt-fonts.ini')]:
        result[output] = render(geometry_block(name), raw, effective)
    for name in ('metrics-fontconfig.tpl', 'metrics-hyprland.tpl'):
        source = (ROOT / 'templates' / name).read_text()
        output = re.search(r'^# theme:out=(.+)$', source, re.M)[1]
        body = '\n'.join(line for line in source.splitlines() if not line.startswith('# theme:')) + '\n'
        result[output] = render(body, raw, effective)
    return result

def generated_defaults():
    raw, effective = resolve({})
    return {
        ROOT.parent / 'quickshell/shared/UiMetricsDefaults.js': '// GENERATED by theme from themes/ui-metrics.toml.\n.pragma library\nvar values = ' + json.dumps(effective, indent=2) + '\n',
        ROOT.parent / 'hypr/ui-metrics-defaults.lua': '-- GENERATED by theme from themes/ui-metrics.toml.\nreturn { radius_window = ' + str(raw['radius_window']) + ' }\n',
    }

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('command', choices=('render-defaults', 'check', 'apply', 'status'))
    args = parser.parse_args()
    if args.command in ('render-defaults', 'check'):
        stale = False
        for path, text in generated_defaults().items():
            if args.command == 'check':
                if not path.exists() or path.read_text() != text:
                    print('stale: ' + str(path.relative_to(ROOT.parent)))
                    stale = True
            else:
                atomic(path, text)
        if stale:
            raise SystemExit(1)
    elif args.command == 'status':
        raw, effective = resolve()
        print(json.dumps({'settings': raw, 'effective': effective}, ensure_ascii=False))
    else:
        for name, text in outputs(preferences()).items():
            atomic(state_dir() / name, text)

if __name__ == '__main__':
    main()
