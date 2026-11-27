import json
import os
import shlex
import subprocess
from pathlib import Path
from socket import gethostname
from time import time

CACHE = Path(os.environ.get('XDG_CACHE_HOME', Path.home() / '.cache')) / 'oninix'
COREDUMP = 'fc2e22bc6ee647b6b90729ab34a250b1'
BROWSERS = {'chrome', 'chromium', '.chromium-wrapped', 'google-chrome', 'msedge'}
KNOWN_CRASHERS = {'.bambu-studio-wrapped': 'Bambu Studio', 'orca-slicer': 'OrcaSlicer'}
JOB_FINISHED = '39f53479d3a045ac8e11786248231fbf'
MAINTENANCE = {
    'oninix-backup.service': 'Backup',
    'oninix-backup-check.service': 'Backup restore check',
    'nix-gc.service': 'Nix garbage collection',
    'fstrim.service': 'SSD trim',
    'fwupd-refresh.service': 'Firmware metadata refresh',
    'oninix-update-check.service': 'OniNix update check',
}


def command(*args, timeout=15):
    try:
        return subprocess.run(args, capture_output=True, text=True, errors='replace',
                              timeout=timeout, env={**os.environ, 'LC_ALL': 'C.UTF-8'})
    except (OSError, subprocess.TimeoutExpired) as error:
        return subprocess.CompletedProcess(args, 127, '', str(error))


def journal(*matches, fields, since='24 hours ago', limit=100):
    count = [] if limit is None else ['-n', str(limit)]
    result = command('journalctl', '--since', since, '--no-pager', '--quiet', '--output=json',
                     '--output-fields=' + ','.join(fields), *count, *matches)
    entries = []
    if result.returncode == 0:
        for line in result.stdout.splitlines():
            try:
                entry = json.loads(line)
                if isinstance(entry, dict):
                    entries.append(entry)
            except ValueError:
                continue
    return result.returncode == 0, entries


def coredumps(since='24 hours ago'):
    available, entries = journal('MESSAGE_ID=' + COREDUMP,
                                 fields=['COREDUMP_COMM', 'COREDUMP_UID', 'COREDUMP_EXE',
                                         'COREDUMP_SIGNAL', 'COREDUMP_CMDLINE'],
                                 since=since, limit=None)
    return available, [entry for entry in entries if event_time_us(entry) > 0]


def crash_name(entry):
    return Path(str(entry.get('COREDUMP_EXE') or '')).name or str(entry.get('COREDUMP_COMM') or 'Process')


def tooling_crash(entry):
    exe = str(entry.get('COREDUMP_EXE') or '')
    if exe.startswith((str(Path.home() / 'Projects') + '/', '/tmp/')):
        return 'in dev builds'
    line = entry.get('COREDUMP_CMDLINE')
    if crash_name(entry) in BROWSERS and isinstance(line, str):
        try:
            args = shlex.split(line)[1:]
        except ValueError:
            return None
        if any(arg == '--headless' or arg.startswith('--headless=') for arg in args):
            return 'headless browser'
    return None


def known_crash(entry):
    if str(entry.get('COREDUMP_SIGNAL')) == '11':
        return KNOWN_CRASHERS.get(Path(str(entry.get('COREDUMP_EXE') or '')).name)
    return None


def failed_units(*scope):
    result = command('systemctl', *scope, 'list-units', '--failed', '--plain', '--no-legend',
                     '--no-pager')
    if result.returncode:
        return None
    return [line.split()[0] for line in result.stdout.splitlines() if line.split()]


def event_time(entry):
    return event_time_us(entry) // 1000000


def event_time_us(entry):
    try:
        return int(entry['__REALTIME_TIMESTAMP'])
    except (KeyError, ValueError, TypeError):
        return 0


def timeline(crashes):
    _, jobs = journal('MESSAGE_ID=' + JOB_FINISHED, fields=['UNIT', 'USER_UNIT', 'JOB_RESULT'])
    events = []
    for job in jobs:
        unit = job.get('UNIT', job.get('USER_UNIT', ''))
        result = job.get('JOB_RESULT', 'done')
        if unit in MAINTENANCE or unit.startswith('btrfs-scrub@') or result != 'done':
            label = MAINTENANCE.get(unit, unit)
            outcome = '' if result == 'done' else f' ({result})'
            events.append({'at': event_time(job), 'level': 'ok' if result == 'done' else 'fail',
                           'text': label + outcome})
    for entry in crashes:
        if tooling_crash(entry):
            continue
        known = known_crash(entry)
        events.append({'at': event_time(entry), 'level': 'info' if known else 'warn',
                       'text': f'{known} crashed (known, ignored)' if known else crash_name(entry) + ' crashed'})
    _, modes = journal('SYSLOG_IDENTIFIER=oninix-mode', fields=['MESSAGE'])
    events.extend({'at': event_time(entry), 'level': 'info', 'text': entry['MESSAGE']}
                  for entry in modes if isinstance(entry.get('MESSAGE'), str))
    boot = Path('/proc/stat').read_text()
    for line in boot.splitlines():
        if line.startswith('btime '):
            start = int(line.split()[1])
            if start >= time() - 86400:
                events.append({'at': start, 'level': 'info', 'text': 'Booted'})
    return sorted(events, key=lambda event: event['at'], reverse=True)[:40]


def report(results, rebuild, crashes):
    return {
        'checked': int(time()),
        'host': gethostname(),
        'level': max((item['level'] for item in results), key=('ok', 'warn', 'fail').index),
        'results': results,
        'rebuild': rebuild,
        'events': timeline(crashes),
    }
