#!/usr/bin/env python3
from datetime import datetime, timedelta
import json
from pathlib import Path
import time

home = Path.home()
if str(home) != '/home/demo':
    raise SystemExit('Use the isolated /home/demo account.')
notes = home / 'Documents/Notes/Quick Notes'
notes.mkdir(parents=True, exist_ok=True)
(notes.parent / '.obsidian').mkdir(exist_ok=True)
samples = {
    'Weekend build': '# Weekend build\n\nSmall changes, useful results.\n\n- [x] Clean up the workspace\n- [x] Choose a quiet color palette\n- [ ] Test the new keyboard shortcuts\n- [ ] Share a few screenshots\n\n#desktop #ideas\n',
    'Music sketch': '# Music sketch\n\n**Tempo:** 92 BPM\n**Key:** D minor\n\nStart with a soft pad and a simple bass line.\nLeave room for the guitar.\n\n- [ ] Record an eight-bar loop\n- [ ] Try a warmer drum sound\n\n#music\n',
    'Things to remember': '# Things to remember\n\nSuper + Space opens search.\nSuper + N opens these notes.\n\nEverything here is a plain Markdown file.\n\n#notes #workflow\n',
}
for title, content in samples.items():
    (notes / (title + '.md')).write_text(content)
now = datetime.now().astimezone()
events = []
for title, offset, length, kind in [('Design review', 20, 30, 'work'), ('Evening practice', 90, 45, 'personal'), ('Plan the next week', 1500, 25, 'personal')]:
    start = now + timedelta(minutes=offset)
    events.append(dict(t=title, s=start.isoformat(), e=(start + timedelta(minutes=length)).isoformat(), a=False, c=kind, cn=kind.title()))
cache = home / '.cache'
cache.mkdir(exist_ok=True)
(cache / 'caldash.json').write_text(json.dumps(dict(ts=time.time(), configured=True, events=events,
    cals={'work': {'name':'Work demo','ok':True},'personal':{'name':'Personal demo','ok':True}}, days={}, clocks={})))
state = home / '.local/state/theme'
state.mkdir(parents=True, exist_ok=True)
(state / 'panels.json').write_text(json.dumps({'style':'islands'}))
(state / 'shell.json').write_text(json.dumps(dict(layout='classic', panelWidth=94, panelHeight=40, panelRadius=12,
    panelOpacity=100, groupStrength=12, buttonMode='groups', buttonStrength=25,
    groupTones={'launchers':'neutral','workspaces':'accent','status':'blue','media':'green','window':'accent','metrics':'blue'})))
