import ast
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal, localcontext
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time
from urllib.parse import quote
import uuid

HOME = Path.home()
STATE = Path(os.environ.get('ONINIX_NOTEBOOK_STATE', str(Path(os.environ.get('XDG_STATE_HOME', HOME / '.local/state')) / 'oninix/notebook')))
DEFAULT_VAULT = HOME / 'Documents/Obsidian'
MAX_NOTE = 512 * 1024

class NotebookError(ValueError):
    def __init__(self, code, message):
        super().__init__(message)
        self.code = code

def atomic(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix='.' + path.name + '-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w', encoding='utf-8', newline='') as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(tmp, path)
        directory = os.open(path.parent, os.O_RDONLY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        Path(tmp).unlink(missing_ok=True)

def read_json(name, fallback):
    path = STATE / name
    return json.loads(path.read_text()) if path.exists() else fallback

def write_json(name, value):
    atomic(STATE / name, json.dumps(value, ensure_ascii=False) + '\n')

@contextmanager
def locked():
    STATE.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (STATE / 'lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield

def vault():
    return Path(read_json('settings.json', {}).get('vault', str(DEFAULT_VAULT))).expanduser().resolve()

def notes_dir():
    root = vault()
    if not root.is_dir() or not (root / '.obsidian').is_dir():
        raise NotebookError('vault', 'Open your Obsidian vault once, or choose its folder in Settings.')
    folder = root / 'Quick Notes'
    if folder.is_symlink():
        raise NotebookError('path', 'Quick Notes must be a directory inside the vault, not a link.')
    folder.mkdir(exist_ok=True)
    return folder

def note_path(name):
    if not isinstance(name, str) or Path(name).name != name or not name.endswith('.md') or name.startswith('.'):
        raise NotebookError('path', 'Invalid note name.')
    path = notes_dir() / name
    if path.is_symlink():
        raise NotebookError('path', 'Linked notes must be edited in Obsidian.')
    return path

def editor_text(raw):
    return raw.replace('\r\n', '\n').replace('\r', '\n')

def note_revision(raw):
    return 'markdown-v3:' + hashlib.sha256(raw.encode('utf-8')).hexdigest()

@dataclass
class NoteParts:
    bom: str
    front: str
    leading: str
    heading: str
    title: str
    body: str
    newline: str

    def render(self, title, body):
        endings = re.findall(r'\r\n|\n|\r', self.body)
        if editor_text(body) == editor_text(self.body):
            body = self.body
        else:
            lines = editor_text(body).split('\n')
            if len(endings) != len(lines) - 1:
                endings = [(endings[0] if endings else self.newline)] * (len(lines) - 1)
            body = ''.join(line + ending for line, ending in zip(lines, endings)) + lines[-1]
        heading, leading = self.heading, ''
        if heading and body.startswith(self.leading):
            leading, body = self.leading, body[len(self.leading):]
        if heading and title != self.title:
            match = re.fullmatch(r'(#[ \t]+)([^\r\n]*)(\r\n|\n|\r|)', heading)
            heading = match[1] + title + match[3]
        elif not heading and title != self.title:
            leading = re.match(r'(?:[ \t]*(?:\r\n|\n|\r))*', body).group()
            body = body[len(leading):]
            heading = '# ' + title + self.newline
        if heading and not heading.endswith(('\n', '\r')) and body:
            heading += self.newline
        content = leading + heading + body
        separator = self.newline if self.front and not self.front.endswith(('\n', '\r')) and content else ''
        return self.bom + self.front + separator + content

def split_note(raw, name):
    bom = '\ufeff' if raw.startswith('\ufeff') else ''
    raw = raw[len(bom):]
    ending = re.search(r'\r\n|\n|\r', raw)
    newline = ending.group() if ending else '\n'
    front = ''
    lines = raw.splitlines(keepends=True)
    if lines and lines[0].rstrip('\r\n') == '---':
        for index, line in enumerate(lines[1:], 1):
            if line.rstrip('\r\n') == '---':
                front = ''.join(lines[:index + 1])
                raw = raw[len(front):]
                break
    leading = re.match(r'(?:[ \t]*(?:\r\n|\n|\r))*', raw).group()
    raw = raw[len(leading):]
    title = Path(name).stem
    heading = ''
    match = re.match(r'#[ \t]+([^\r\n]*)(?:\r\n|\n|\r|$)', raw)
    if match:
        heading, title, raw = match.group(), match[1].strip(), raw[match.end():]
    raw = leading + raw
    if not heading:
        leading = ''
    return NoteParts(bom, front, leading, heading, title, raw, newline)

def read_note(name):
    path = note_path(name)
    if path.stat().st_size > MAX_NOTE:
        raise NotebookError('size', 'This note is too large for the sidebar. Open it in Obsidian.')
    raw = path.read_bytes().decode('utf-8')
    parts = split_note(raw, name)
    return dict(id=name, title=parts.title, body=editor_text(parts.body), has_heading=bool(parts.heading),
                revision=note_revision(raw), modified=path.stat().st_mtime,
                url='obsidian://open?path=' + quote(str(path), safe=''))

def list_notes(query=''):
    items = []
    paths = sorted(notes_dir().glob('*.md'), key=lambda p: p.lstat().st_mtime, reverse=True)
    for path in paths[:1000]:
        if path.name.startswith(".") or path.is_symlink() or not path.is_file() or path.stat().st_size > MAX_NOTE:
            continue
        try:
            note = read_note(path.name)
        except (UnicodeDecodeError, NotebookError):
            continue
        if query.casefold() not in (note['title'] + '\n' + note['body']).casefold():
            continue
        checks = re.findall(r'^\s*[-*] \[([ xX])\]', note['body'], re.M)
        items.append(dict(id=note['id'], title=note['title'], modified=note['modified'],
                          preview=note['body'].strip()[:140], total=len(checks),
                          done=sum(c.lower() == 'x' for c in checks)))
    return items[:200]

def save_note(request, new=False):
    title = str(request.get('title', '')).strip()
    body = str(request.get('body', ''))
    if '\n' in title or '\r' in title or len(title) > 180 or len(body.encode()) > MAX_NOTE - 2048:
        raise NotebookError('size', 'Use a single-line title and a note smaller than 512 KiB.')
    write_json('draft.json', {k: request.get(k, '') for k in ('id', 'title', 'body', 'revision')})
    day = datetime.now().date().isoformat()
    if new:
        name = datetime.now().strftime('Quick Note %Y-%m-%d %H%M%S-') + uuid.uuid4().hex[:8] + '.md'
        path = note_path(name)
        front = f'---\ncreated: {day}\nupdated: {day}\ntags: [inbox]\nstatus: draft\n---\n'
        content = front + '# ' + (title or 'Untitled note') + '\n' + body
    else:
        name = request.get('id', '')
        path = note_path(name)
        if not path.exists():
            raise NotebookError('conflict', 'This note was moved or removed elsewhere. Save your edit as a copy.')
        raw = path.read_bytes().decode('utf-8')
        if not str(request.get('revision', '')).startswith('markdown-v3:'):
            raise NotebookError('conflict', 'Notebook was updated. Your draft is safe; save a copy or reload the original before editing.')
        if note_revision(raw) != request.get('revision'):
            raise NotebookError('conflict', 'This note changed in Obsidian or Sync. Your draft is safe; save a copy or reload.')
        parts = split_note(raw, name)
        if title == parts.title and editor_text(body) == editor_text(parts.body):
            write_json('draft.json', {})
            return read_note(name)
        if title != parts.title:
            title = title or 'Untitled note'
        if parts.front:
            parts.front = re.sub(r'(?m)^updated:[^\r\n]*', 'updated: ' + day, parts.front)
        content = parts.render(title, body)
        atomic(STATE / 'previous' / name, raw)
    atomic(path, content)
    result = read_note(name)
    write_json('draft.json', {})
    return result

def calculate(expression):
    if not isinstance(expression, str) or not expression.strip() or len(expression) > 256:
        raise NotebookError('calc', 'Enter a short arithmetic expression.')
    try:
        tree = ast.parse(expression.replace('×', '*').replace('÷', '/').replace('^', '**'), mode='eval')
        if len(list(ast.walk(tree))) > 80:
            raise ValueError()
        def evaluate(node, depth=0):
            if depth > 16:
                raise ValueError()
            ev = lambda n: evaluate(n, depth + 1)
            if isinstance(node, ast.Constant) and type(node.value) in (int, float):
                value = Decimal(str(node.value))
            elif isinstance(node, ast.Name) and node.id in ('pi', 'e'):
                value = Decimal({'pi': '3.141592653589793238462643383279503', 'e': '2.718281828459045235360287471352662'}[node.id])
            elif isinstance(node, ast.UnaryOp) and isinstance(node.op, (ast.UAdd, ast.USub)):
                value = ev(node.operand) * (-1 if isinstance(node.op, ast.USub) else 1)
            elif isinstance(node, ast.BinOp):
                a, b = ev(node.left), ev(node.right)
                if isinstance(node.op, ast.Add): value = a + b
                elif isinstance(node.op, ast.Sub): value = a - b
                elif isinstance(node.op, ast.Mult): value = a * b
                elif isinstance(node.op, ast.Div): value = a / b
                elif isinstance(node.op, ast.Mod): value = a % b
                elif isinstance(node.op, ast.Pow) and abs(b) <= 100: value = a ** b
                else: raise ValueError()
            elif isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and len(node.args) == 1 and not node.keywords:
                a = ev(node.args[0])
                if node.func.id == 'sqrt': value = a.sqrt()
                elif node.func.id == 'abs': value = abs(a)
                else: raise ValueError()
            else:
                raise ValueError()
            if not value.is_finite() or abs(value) > Decimal('1e100'):
                raise ValueError()
            return value
        with localcontext() as ctx:
            ctx.prec = 28
            value = evaluate(tree.body)
            return format(value.normalize(), 'f')
    except Exception as exc:
        raise NotebookError('calc', 'Use numbers, + - * / % ^, parentheses, sqrt(), abs(), pi or e.') from exc

def jobs():
    return read_json('reminders.json', [])

def change_job(request):
    values = jobs()
    op = request['op']
    now = time.time()
    if op == 'add':
        if len([j for j in values if j['state'] != 'done']) >= 100:
            raise NotebookError('limit', 'Complete an existing reminder first (limit: 100).')
        kind = request.get('kind', 'reminder')
        if kind not in ('timer', 'reminder'):
            raise ValueError('Invalid reminder kind')
        label = str(request.get('label', '')).strip()[:180] or ('Timer' if kind == 'timer' else 'Reminder')
        duration = float(request.get('seconds', 0))
        due = now + duration if duration else datetime.fromisoformat(request['when']).timestamp()
        if not now < due <= now + 366 * 86400 or (kind == 'timer' and not 1 <= duration <= 86400):
            raise NotebookError('time', 'Choose a future time within a year; timers can run up to 24 hours.')
        values = [j for j in values if j['state'] != 'done'] + [j for j in values if j['state'] == 'done'][-30:]
        values.append(dict(id=uuid.uuid4().hex, label=label, kind=kind, due=due,
                           duration=duration, remaining=duration, state='running', created=now))
    else:
        job = next((j for j in values if j['id'] == request.get('id')), None)
        if not job:
            raise NotebookError('missing', 'This reminder no longer exists.')
        if op == 'done': job['state'] = 'done'
        elif op == 'snooze': job.update(due=now + 600, state='running')
        elif op == 'pause' and job['kind'] == 'timer' and job['state'] == 'running':
            job.update(remaining=max(1, job['due'] - now), state='paused')
        elif op == 'resume' and job['state'] == 'paused':
            job.update(due=now + job['remaining'], state='running')
        else:
            raise NotebookError('state', 'This action is not available for this reminder.')
    write_json('reminders.json', values)
    return values

def tick(notify=None, now=None):
    if not (STATE / 'reminders.json').exists():
        return
    now = time.time() if now is None else now
    if notify is None:
        def notify(job):
            subprocess.run(['notify-send', '-a', 'OniNix Notebook', '-u', 'critical',
                            'Timer finished' if job['kind'] == 'timer' else 'Reminder',
                            job['label'].replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')],
                           check=True, timeout=5, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    with locked():
        values = jobs()
        for job in values:
            if job['state'] == 'running' and job['due'] <= now:
                notify(job)
                job['state'] = 'fired'
                write_json('reminders.json', values)

def handle(request):
    with locked():
        op = request.get('op')
        if op == 'status':
            return dict(vault=str(vault()), available=(vault() / '.obsidian').is_dir(), jobs=jobs(), draft=read_json('draft.json', {}))
        if op == 'vault':
            path = Path(str(request.get('path', ''))).expanduser().resolve()
            if not (path / '.obsidian').is_dir():
                raise NotebookError('vault', 'Choose an existing Obsidian vault folder.')
            write_json('settings.json', {'vault': str(path)})
            return dict(vault=str(path))
        if op == 'list': return list_notes(str(request.get('query', ''))[:200])
        if op == 'read': return read_note(request.get('id', ''))
        if op == 'reload':
            result = read_note(request.get('id', ''))
            write_json('draft.json', {})
            return result
        if op in ('save', 'new'): return save_note(request, new=op == 'new')
        if op == 'calculate': return calculate(request.get('expression', ''))
        if op in ('add', 'done', 'snooze', 'pause', 'resume'): return change_job(request)
        if op == 'copy':
            subprocess.run(['wl-copy', '--', str(request.get('text', ''))[:8192]],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3, check=True)
            return True
        raise NotebookError('request', 'Unknown notebook action.')
