#!/usr/bin/env python3

import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

PATH = Path(__file__).resolve().parents[2] / 'dotfiles/.local/bin/station-desktop'
spec = importlib.util.spec_from_loader('desktop', importlib.machinery.SourceFileLoader('desktop', str(PATH)))
desktop = importlib.util.module_from_spec(spec)
spec.loader.exec_module(desktop)

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

    def test_click_invokes_only_default_and_removes_item(self):
        desktop.action('notification-open', ['3'])
        self.assertIn(['makoctl', 'invoke', '-n', '3', '--', 'default'], self.calls)
        self.assertEqual(desktop.notifications()['current'], [])
        self.assertEqual([n['id'] for n in desktop.notifications()['history']], [1, 2])

    def test_non_default_action_is_not_guessed(self):
        self.current[0]['actions'] = {'delete': 'Delete permanently'}
        desktop.action('notification-open', ['3'])
        self.assertFalse(any(c[0:2] == ['makoctl', 'invoke'] for c in self.calls))
        self.assertEqual(desktop.notifications()['unread'], 2)

    def test_default_action_may_close_notification_itself(self):
        original_run = self.fake_run
        def closing_action(args, *a, **kw):
            result = original_run(args, *a, **kw)
            if args[:2] == ['makoctl', 'invoke']:
                self.current = []
            return result
        with patch.object(desktop, 'run', closing_action):
            desktop.action('notification-open', ['3'])
        self.assertFalse(any(c[:2] == ['makoctl', 'dismiss'] for c in self.calls))
        self.assertEqual(desktop.notifications()['current'], [])

    def test_history_dismissals_stay_hidden_and_restart_resets_marks(self):
        desktop.action('dismiss', ['1']); desktop.action('dismiss', ['2'])
        self.assertEqual(desktop.notifications()['history'], [])
        self.owner = ':1.11'
        self.assertEqual(len(desktop.notifications()['history']), 2)

    def test_clear_marks_read_but_new_notifications_survive(self):
        desktop.action('clear', [])
        self.assertEqual(desktop.notifications()['unread'], 0)
        self.assertEqual(desktop.notifications()['history'], [])
        self.current = [{'id': 4}]
        self.assertEqual(desktop.notifications()['current'], [{'id': 4, 'tier': 'normal'}])
        self.assertEqual(desktop.notifications()['unread'], 1)

if __name__ == '__main__':
    unittest.main()
