from pathlib import Path
import sys
import tomllib

palette_path, source_path, output_path = map(Path, sys.argv[1:])
palette = tomllib.loads(palette_path.read_text())
replacements = {'@THEME_DIR@': str(output_path / 'share/plymouth/themes/oninix')}
for name, value in palette.items():
    if isinstance(value, str) and value.startswith('#'):
        replacements[f'@{name}@'] = value
        for component, offset in [('R', 1), ('G', 3), ('B', 5)]:
            replacements[f'@{name}{component}@'] = str(int(value[offset:offset + 2], 16) / 255)
for source, destination in [
    ('grub-theme.txt.in', 'grub/theme.txt'),
    ('oninix.plymouth.in', 'share/plymouth/themes/oninix/oninix.plymouth'),
    ('oninix.script.in', 'share/plymouth/themes/oninix/oninix.script'),
]:
    text = (source_path / source).read_text()
    for token, value in replacements.items():
        text = text.replace(token, value)
    (output_path / destination).write_text(text)
