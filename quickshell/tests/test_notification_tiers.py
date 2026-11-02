#!/usr/bin/env python3

import configparser
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'dotfiles/.local/lib'))
import station_notifications as notes

class TiersTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.env = patch.dict(os.environ, {'XDG_STATE_HOME': self.tmp.name})
        self.env.start()

    def tearDown(self):
        self.env.stop(); self.tmp.cleanup()

    def test_defaults_do_not_import_personal_rules(self):
        self.assertEqual(notes.tier('KDE Connect', 'Example App', notes.load_rules()), 'normal')
        notes.set_rule('Slack', '', 'quiet')
        self.assertEqual(notes.tier('KDE Connect', 'Example App', notes.load_rules()), 'normal')

    def test_title_rule_beats_application_rule(self):
        rules = [{'app': 'Slack', 'summary': '', 'tier': 'quiet'},
                 {'app': 'Slack', 'summary': 'Mention', 'tier': 'important'}]
        self.assertEqual(notes.tier('Slack', 'Mention', rules), 'important')
        self.assertEqual(notes.tier('Slack', 'Other', rules), 'quiet')
        self.assertEqual(notes.tier('Telegram', 'Mention', rules), 'normal')
        conf = notes.mako(list(reversed(rules)))
        self.assertLess(conf.index('[app-name="Slack"]'), conf.index('summary="Mention"'))

    def test_normal_removes_the_rule(self):
        notes.set_rule('Slack', 'Bot', 'hidden')
        notes.set_rule('Slack', 'Bot', 'normal')
        self.assertFalse(any(r['app'] == 'Slack' for r in notes.load_rules()))
        self.assertTrue(notes.mako_path().is_file())

    def test_title_tier_resets_all_inherited_style_properties(self):
        expected = {
            'important': {'invisible': '0', 'history': '1', 'default-timeout': '0', 'ignore-timeout': '1'},
            'quiet': {'invisible': '1', 'history': '1', 'default-timeout': '1', 'ignore-timeout': '1'},
            'hidden': {'invisible': '1', 'history': '0', 'default-timeout': '1', 'ignore-timeout': '1'},
        }
        for app_tier in expected:
            for title_tier, wanted in expected.items():
                with self.subTest(app=app_tier, title=title_tier):
                    config = configparser.ConfigParser(interpolation=None)
                    config.read_string(notes.mako([
                        {'app': 'Slack', 'summary': '', 'tier': app_tier},
                        {'app': 'Slack', 'summary': 'Mention', 'tier': title_tier},
                    ]))

                    style = dict(config['app-name="Slack"'])
                    style.update(config['app-name="Slack" summary="Mention"'])
                    self.assertEqual(style, wanted)
                    style.update(config['urgency=critical'])
                    style.update(config['mode=do-not-disturb'])
                    style.update(config['mode=do-not-disturb urgency=critical'])
                    self.assertEqual(style, expected['important'])

    def test_mako_quotes_values_and_guards_critical_and_dnd(self):
        conf = notes.mako([{'app': 'KDE "Connect"', 'summary': 'a\\b', 'tier': 'hidden'}])
        self.assertIn(r'[app-name="KDE \"Connect\"" summary="a\\b"]', conf)
        self.assertIn('history=0', conf)
        tail = conf[conf.index('[urgency=critical]'):]
        self.assertIn('invisible=0', tail)
        self.assertIn('[mode=do-not-disturb]\ninvisible=1', tail)

    def test_rejects_multiline_and_unknown_tiers(self):
        with self.assertRaises(ValueError):
            notes.set_rule('Slack', 'a\n[urgency=critical]', 'quiet')
        with self.assertRaises(ValueError):
            notes.set_rule('Slack', '', 'loud')
        notes.rules_path().parent.mkdir(parents=True, exist_ok=True)
        notes.rules_path().write_text(json.dumps({'rules': [{'app': 'X', 'summary': '', 'tier': 'loud'}]}))
        self.assertEqual(notes.load_rules(), [])

    def test_monitor_pairs_calls_with_ids_and_records_outcomes(self):
        rows = []
        monitor = notes.Monitor(rows.append)
        monitor.feed({'type': 'method_call', 'member': 'Notify', 'sender': ':1.5', 'cookie': 10, 'payload': {
            'data': ['Slack', 0, '', 'New message in bots', 'secret body', [], {'urgency': {'data': 1}}, -1]}})
        monitor.feed({'type': 'method_return', 'sender': ':1.12', 'destination': ':1.5', 'reply_cookie': 10, 'payload': {'data': [42]}})
        monitor.feed({'type': 'method_return', 'sender': ':1.12', 'destination': ':1.6', 'reply_cookie': 10, 'payload': {'data': [43]}})
        monitor.feed({'type': 'signal', 'member': 'ActionInvoked', 'sender': ':1.12', 'payload': {'data': [42, 'default']}})
        monitor.feed({'type': 'signal', 'member': 'NotificationClosed', 'sender': ':1.12', 'payload': {'data': [42, 3]}})
        self.assertEqual([r['e'] for r in rows], ['notify', 'action', 'closed'])
        self.assertEqual(rows[0]['id'], 42)
        self.assertNotIn('secret body', json.dumps(rows))

    def test_stats_and_suggestions_from_the_log(self):
        now = 1_800_000_000
        for i in range(10):
            notes.append({'e': 'notify', 'o': ':1.12', 'id': i, 'app': 'Slack', 'summary': 'New message in bots'}, now - 60)
        notes.append({'e': 'notify', 'o': ':1.12', 'id': 50, 'app': 'Slack', 'summary': 'Direct'}, now - 60)
        for i in range(10, 20):
            notes.append({'e': 'notify', 'o': ':1.12', 'id': i, 'app': 'Telegram', 'summary': 'Chat'}, now - 60)
            notes.append({'e': 'action', 'o': ':1.12', 'id': i, 'key': 'default'}, now - 50)
        notes.append({'e': 'notify', 'o': ':1.12', 'id': 99, 'app': 'Old', 'summary': 'x'}, now - 30 * 86400)
        stats = notes.stats(7, now, rules=[])
        self.assertEqual(stats[0]['count'], 10)
        self.assertNotIn('Old', [s['app'] for s in stats])
        self.assertEqual([(s['app'], s['summary']) for s in notes.suggestions(7, now, rules=[])], [('Slack', 'New message in bots')])
        quiet = [{'app': 'Slack', 'summary': 'New message in bots', 'tier': 'quiet'}]
        self.assertEqual(notes.suggestions(7, now, rules=quiet), [])
        mode = (notes.log_dir() / os.listdir(notes.log_dir())[0]).stat().st_mode & 0o777
        self.assertEqual(mode, 0o600)
        notes.prune(now)
        self.assertEqual(len(notes.read_log(60, now)), 31)

if __name__ == '__main__':
    unittest.main()
