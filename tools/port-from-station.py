#!/usr/bin/env python3
import re
import sys
from pathlib import Path

SHARE_LUA = '(os.getenv("ONINIX_SHARE") or "/run/current-system/sw/share/oninix")'
HOME_LUA = r'(?:\(os\.getenv\("HOME"\) or ""\)|os\.getenv\("HOME"\)|\bhome)'

RULES = [
    (re.compile(r'"quickshell -p " \.\. ' + HOME_LUA + r' \.\. "/\.config/quickshell/station\.qml ipc'), '"oninix-shell ipc'),
    (re.compile(r'"quickshell -n -p " \.\. ' + HOME_LUA + r' \.\. "/\.config/quickshell/station\.qml'), '"oninix-shell'),
    (re.compile(HOME_LUA + r' \.\. "/\.local/bin/station-'), '"oninix-'),
    (re.compile(HOME_LUA + r' \.\. "/\.local/bin/theme'), '"oninix-theme'),
    (re.compile(HOME_LUA + r' \.\. "/\.config/hypr/'), SHARE_LUA + ' .. "/hypr/'),
    (re.compile(r'"?\$HOME/\.local/bin/station-([a-z-]+)"?'), r'oninix-\1'),
    (re.compile(r'"?\$HOME/\.local/bin/theme"?'), 'oninix-theme'),
    (re.compile(r'\$HOME/\.config/hypr/'), '${ONINIX_SHARE:-/run/current-system/sw/share/oninix}/hypr/'),
    (re.compile(r'Quickshell\.env\((["\'])HOME\1\) \+ (["\'])/\.local/bin/(?:station-|oninix-)'), r'\2oninix-'),
    (re.compile(r'Quickshell\.env\((["\'])HOME\1\) \+ (["\'])/\.local/bin/theme'), r'\2oninix-theme'),
    (re.compile(r'Quickshell\.env\((["\'])HOME\1\) \+ (["\'])/\.local/bin/cheatsheet-helper'), r'\2oninix-cheatsheet-helper'),
    (re.compile(r'Quickshell\.env\((["\'])HOME\1\) \+ (["\'])/\.config/hypr/monitors\.conf'), r'Quickshell.env(\1HOME\1) + \2/.config/oninix/monitors.conf'),
    (re.compile(r'Quickshell\.env\((["\'])HOME\1\) \+ (["\'])/\.config/(hypr|quickshell)/'), r'Quickshell.env(\1ONINIX_SHARE\1) + \2/\3/'),
    (re.compile(r'/Nextcloud/Img/Screenshots'), '/Pictures/Screenshots'),
    (re.compile(r"(['\"])station/"), r"\1oninix/"),
    (re.compile(r"/ (['\"])station\1"), r"/ \1oninix\1"),
    (re.compile(r'\bSTATION_STATE\b'), 'ONINIX_STATE'),
    (re.compile(r'X-Station-'), 'X-OniNix-'),
    (re.compile(r'\bstation-(desktop|display|launcher|maintenance|doctor|audio|theme|profile|phone-clip|status|panel)\b'), r'oninix-\1'),
    (re.compile(r'\bSTATION_([A-Z][A-Z_]*)\b'), r'ONINIX_\1'),
    (re.compile(r'\bstation-([a-z][a-z-]*)'), r'oninix-\1'),
    (re.compile(r'\bstationEase\b'), 'oninixEase'),
    (re.compile(r'/station/'), '/oninix/'),
    (re.compile(r'/station-desktop/'), '/oninix-desktop/'),
]

def port(path):
    text = path.read_text()
    total = 0
    for pattern, replacement in RULES:
        text, count = pattern.subn(replacement, text)
        total += count
    path.write_text(text)
    return total

if __name__ == '__main__':
    for name in sys.argv[1:]:
        print(f'{port(Path(name)):4d}  {name}')
