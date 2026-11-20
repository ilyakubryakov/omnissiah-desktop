"""Notification tiers, the generated mako rules and the local delivery log.

Tiers: important (stays until answered), normal, quiet (history only, no popup),
hidden (discarded). Rules match the application and, optionally, the exact title;
a title rule beats an application rule. Critical alerts and do-not-disturb always
win, except Gaming mode which pauses every popup. The log keeps application,
title, urgency and what happened, never bodies. The feed is a separate stream with
bodies for Vika (personal_assistant bin/notifications), same retention.
"""
import json
import os
from pathlib import Path
import re
import time

TIERS = ('important', 'quiet', 'hidden')
KEEP_DAYS = 21
URGENCY = ('low', 'normal', 'critical')
DEFAULT_RULES = [
    # Bank confirmations and codes arrive through the phone; never quiet them.
    {'app': 'KDE Connect', 'summary': 'Revolut', 'tier': 'important'},
    {'app': 'KDE Connect', 'summary': 'Swedbank', 'tier': 'important'},
]
STYLE = {
    # Mako merges matching rules property by property; reset the parent tier fully.
    'important': ['invisible=0', 'history=1', 'default-timeout=0', 'ignore-timeout=1'],
    'quiet': ['invisible=1', 'history=1', 'default-timeout=1', 'ignore-timeout=1'],
    'hidden': ['invisible=1', 'history=0', 'default-timeout=1', 'ignore-timeout=1'],
}
GUARD = """# Critical alerts and do-not-disturb always win over the rules above.
[urgency=critical]
invisible=0
history=1
default-timeout=0
ignore-timeout=1

[mode=do-not-disturb]
invisible=1

[mode=do-not-disturb urgency=critical]
invisible=0

# Action buttons are presented by Quickshell, with the same tier/DND guards.
[actionable=1]
invisible=1

# Last, after tier and critical overrides: Gaming pauses every popup.
[mode=gaming]
invisible=1
"""


def state():
    return Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'oninix'


def rules_path():
    return state() / 'notification-rules.json'


def mako_path():
    return state() / 'notification-rules.conf'


def log_dir():
    return state() / 'notification-log'


def feed_dir():
    return state() / 'notification-feed'


def clean(text):
    if not isinstance(text, str) or len(text) > 200 or re.search(r'[\x00-\x1f\x7f]', text):
        raise ValueError('Notification rules take a single line of up to 200 characters')
    return text


def valid(rule):
    try:
        return (isinstance(rule, dict) and rule.get('tier') in TIERS
                and clean(rule.get('app')) != '' and clean(rule.get('summary', '')) is not None)
    except ValueError:
        return False


def load_rules():
    try:
        data = json.loads(rules_path().read_text())
    except FileNotFoundError:
        return [dict(r) for r in DEFAULT_RULES]
    except (OSError, ValueError):
        return []
    rows = data.get('rules', []) if isinstance(data, dict) else []
    return [{'app': r['app'], 'summary': r.get('summary', ''), 'tier': r['tier']} for r in rows if valid(r)]


def atomic(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name('.' + path.name + '.tmp')
    tmp.write_text(text)
    tmp.replace(path)


def save_rules(rules):
    atomic(rules_path(), json.dumps({'rules': rules}, indent=1, ensure_ascii=False) + '\n')
    render(rules)


def set_rule(app, summary, tier):
    app, summary = clean(app), clean(summary)
    if not app or tier not in TIERS + ('normal',):
        raise ValueError('Unknown notification rule')
    rules = [r for r in load_rules() if (r['app'], r['summary']) != (app, summary)]
    if tier != 'normal':
        rules.append({'app': app, 'summary': summary, 'tier': tier})
    save_rules(rules)
    return rules


def tier(app, summary, rules):
    for r in rules:
        if r['app'] == app and r['summary'] and r['summary'] == summary:
            return r['tier']
    for r in rules:
        if r['app'] == app and not r['summary']:
            return r['tier']
    return 'normal'


def quote(value):
    return '"' + value.replace('\\', '\\\\').replace('"', '\\"') + '"'


def mako(rules):
    out = ['# Generated from notification-rules.json by oninix-desktop; edits are replaced.', '']
    # Application rules first, so a title rule for the same application wins.
    for r in sorted(rules, key=lambda r: bool(r['summary'])):
        head = 'app-name=' + quote(r['app'])
        if r['summary']:
            head += ' summary=' + quote(r['summary'])
        out += ['[' + head + ']'] + STYLE[r['tier']] + ['']
    return '\n'.join(out) + GUARD


def render(rules=None):
    atomic(mako_path(), mako(load_rules() if rules is None else rules))


# ---- delivery log -----------------------------------------------------------

def append(record, now=None, directory=None):
    now = time.time() if now is None else now
    directory = log_dir() if directory is None else directory
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    path = directory / (time.strftime('%Y-%m-%d', time.localtime(now)) + '.jsonl')
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
    with os.fdopen(fd, 'a') as stream:
        stream.write(json.dumps(dict(record, t=round(now, 3)), ensure_ascii=False) + '\n')


def append_feed(record, now=None):
    append(record, now, feed_dir())


def prune(now=None):
    now = time.time() if now is None else now
    cutoff = time.strftime('%Y-%m-%d', time.localtime(now - KEEP_DAYS * 86400))
    for directory in (log_dir(), feed_dir()):
        for path in directory.glob('*.jsonl'):
            if path.stem < cutoff:
                path.unlink(missing_ok=True)


def read_log(days, now=None):
    now = time.time() if now is None else now
    since, rows = now - days * 86400, []
    for path in sorted(log_dir().glob('*.jsonl')):
        try:
            lines = path.read_text().splitlines()
        except OSError:
            continue
        for line in lines:
            try:
                row = json.loads(line)
            except ValueError:
                continue
            if isinstance(row, dict) and row.get('t', 0) >= since:
                rows.append(row)
    return rows


class Monitor:
    """Turns `busctl --user monitor --json=short org.freedesktop.Notifications` into log records.
    The optional feed writer also gets each arrival with its body and the id it replaces."""

    def __init__(self, write, feed=None):
        self.write, self.feed_write, self.pending = write, feed, {}

    def feed(self, message, now=None):
        now = time.time() if now is None else now
        kind, member = message.get('type'), message.get('member')
        data = (message.get('payload') or {}).get('data') or []
        if kind == 'method_call' and member == 'Notify' and len(data) >= 7:
            hints = data[6] if isinstance(data[6], dict) else {}
            level = (hints.get('urgency') or {}).get('data', 1)
            self.pending = {k: v for k, v in self.pending.items() if now - v['at'] < 30}
            self.pending[(message.get('sender'), message.get('cookie'))] = {
                'at': now, 'app': str(data[0]), 'summary': str(data[3]), 'body': str(data[4]),
                'replaces': data[1] if isinstance(data[1], int) else 0,
                'entry': str((hints.get('desktop-entry') or {}).get('data', '')),
                'urgency': URGENCY[level] if level in (0, 1, 2) else 'normal'}
        elif kind == 'method_return':
            call = self.pending.pop((message.get('destination'), message.get('reply_cookie')), None)
            if call and data:
                self.write({'e': 'notify', 'o': message.get('sender'), 'id': data[0],
                            'app': call['app'], 'summary': call['summary'], 'urgency': call['urgency']})
                if self.feed_write:
                    self.feed_write({'o': message.get('sender'), 'id': data[0], 'replaces': call['replaces'],
                                     'app': call['app'], 'entry': call['entry'], 'summary': call['summary'],
                                     'body': call['body'], 'urgency': call['urgency']})
        elif kind == 'signal' and member == 'ActionInvoked' and len(data) == 2:
            self.write({'e': 'action', 'o': message.get('sender'), 'id': data[0], 'key': str(data[1])})
        elif kind == 'signal' and member == 'NotificationClosed' and len(data) == 2:
            self.write({'e': 'closed', 'o': message.get('sender'), 'id': data[0], 'reason': data[1]})


def stats(days=7, now=None, rules=None):
    rules = load_rules() if rules is None else rules
    rows = read_log(days, now)
    acted = {(r.get('o'), r.get('id')) for r in rows if r.get('e') == 'action'}
    dismissed = {(r.get('o'), r.get('id')) for r in rows if r.get('e') == 'closed' and r.get('reason') == 2}
    table = {}
    for r in rows:
        if r.get('e') != 'notify':
            continue
        key = (r.get('app', ''), r.get('summary', ''))
        item = table.setdefault(key, {'app': key[0], 'summary': key[1], 'count': 0, 'opened': 0, 'dismissed': 0,
                                      'tier': tier(key[0], key[1], rules)})
        item['count'] += 1
        item['opened'] += (r.get('o'), r.get('id')) in acted
        item['dismissed'] += (r.get('o'), r.get('id')) in dismissed
    return sorted(table.values(), key=lambda i: -i['count'])


def suggestions(days=7, now=None, rules=None, limit=3):
    """Titles (or whole applications) that keep arriving and are never opened."""
    rules = load_rules() if rules is None else rules
    rows, out, apps = stats(days, now, rules), [], {}
    for item in rows:
        app = apps.setdefault(item['app'], {'count': 0, 'opened': 0, 'titles': 0})
        app['count'] += item['count']; app['opened'] += item['opened']; app['titles'] += 1
    for name, app in sorted(apps.items(), key=lambda kv: -kv[1]['count']):
        if app['titles'] > 3 and app['count'] >= 20 and not app['opened'] and tier(name, '', rules) == 'normal' \
                and not any(r['app'] == name for r in rules):
            out.append({'app': name, 'summary': '', 'count': app['count']})
    covered = {s['app'] for s in out}
    for item in rows:
        if item['app'] not in covered and item['count'] >= 8 and not item['opened'] and item['tier'] == 'normal':
            out.append({'app': item['app'], 'summary': item['summary'], 'count': item['count']})
    return sorted(out, key=lambda s: -s['count'])[:limit]
