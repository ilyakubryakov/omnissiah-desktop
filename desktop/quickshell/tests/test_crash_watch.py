import os
from pathlib import Path
import runpy
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

DESKTOP = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(DESKTOP / 'lib'))
import oninix_health as health

class CrashWatchTests(unittest.TestCase):
    def setUp(self):
        directory = self.enterContext(tempfile.TemporaryDirectory())
        self.path = Path(directory) / 'oninix/crash-watch'
        self.enterContext(patch.dict(os.environ, XDG_STATE_HOME=directory))

    def dump(self, name, at, uid=None, exe=None):
        return {
            'COREDUMP_UID': str(os.getuid() if uid is None else uid),
            'COREDUMP_COMM': name,
            'COREDUMP_EXE': exe or '/bin/' + name,
            '__REALTIME_TIMESTAMP': str(at * 1_000_000),
        }

    def watch(self, entries, at):
        with patch('time.time', return_value=at), \
                patch.object(health, 'coredumps', return_value=(True, entries)) as journal, \
                patch.object(health, 'command', return_value=SimpleNamespace(returncode=0)) as notify:
            runpy.run_path(str(DESKTOP / 'bin/oninix-crash-watch'))
        return journal, notify

    def test_old_and_other_user_crashes_do_not_repeat(self):
        entries = [self.dump('editor', 900), self.dump('daemon', 901, uid=os.getuid() + 1)]
        journal, notify = self.watch(entries, 1000)
        journal.assert_called_once_with('@700')
        self.assertIn('editor x1', notify.call_args.args[-1])
        self.assertEqual(self.path.read_text().strip(), '1000')
        journal, notify = self.watch(entries, 1010)
        journal.assert_called_once_with('@1000')
        notify.assert_not_called()

    @unittest.skipUnless(hasattr(health, 'tooling_crash'), 'requires the updated crash watcher')
    def test_uses_executable_and_skips_temporary_builds(self):
        entries = [self.dump('editor-bin', 900, exe='/bin/editor'),
                   self.dump('debug', 901, exe='/tmp/build/editor')]
        _, notify = self.watch(entries, 1000)
        self.assertEqual(notify.call_args.args[-1], 'editor x1')
