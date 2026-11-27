#!/usr/bin/env python3
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

PATH = Path(__file__).resolve().parents[2] / 'bin/oninix-desktop'
spec = importlib.util.spec_from_loader('desktop', importlib.machinery.SourceFileLoader('desktop', str(PATH)))
desktop = importlib.util.module_from_spec(spec)
spec.loader.exec_module(desktop)

@unittest.skipUnless(hasattr(desktop.notes, "update_marker"), "requires the notification logging backend")
class NotificationsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.env = patch.dict(os.environ, {'XDG_RUNTIME_DIR': self.tmp.name, 'XDG_STATE_HOME': self.tmp.name})
        self.env.start()
        self.owner = ':1.10'
        self.current = [{'id': 3, 'summary': 'Actionable', 'actions': {'default': 'Open'}}]
        self.history = [{'id': 1}, {'id': 2}]
        self.calls = []
        self.runner = patch.object(desktop, 'run', self.fake_run)
        self.runner.start()

    def tearDown(self):
        self.runner.stop(); self.env.stop(); self.tmp.cleanup()

    def fake_run(self, args, *a, **kw):
        self.calls.append(args)
        if args[0] == 'busctl':
            return ('s "' + self.owner + '"').encode()
        if args[1] in ('list', 'history'):
            return json.dumps({'data': [self.current] if args[1] == 'list' else self.history}).encode()
        if args[1] == 'dismiss':
            if '--all' in args:
                self.current = []
            else:
                self.current = [n for n in self.current if str(n['id']) != args[3]]
        return b''

    def test_popup_creates_marker_without_touching_it_again(self):
        marker = Path(self.tmp.name) / 'oninix-mako-notify'
        desktop.notifications(popup_only=True)
        self.assertTrue(marker.is_file())
        os.utime(marker, (1000, 1000))
        desktop.notifications(popup_only=True)
        self.assertEqual(marker.stat().st_mtime, 1000)
        self.assertFalse(any(c[0] == 'busctl' for c in self.calls))

    def test_copy_code_is_sensitive_and_uses_stdin(self):
        self.current = [{'id': 3, 'summary': 'Verification code', 'body': 'Your code is 198432'}]
        with patch.object(desktop.subprocess, 'run') as command:
            desktop.action('notification-copy-code', ['3'])
        self.assertEqual(command.call_args.args, (['wl-copy', '--sensitive'],))
        self.assertEqual(command.call_args.kwargs['input'], b'198432')

    def test_qml_watches_the_same_marker(self):
        panel = PATH.parents[1] / 'quickshell/bar/ActionNotifications.qml'
        self.assertIn('Quickshell.env("XDG_RUNTIME_DIR") + "/oninix-mako-notify"', panel.read_text())
