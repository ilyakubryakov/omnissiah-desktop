#!/usr/bin/env python3
import importlib.machinery
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

PATH = Path(__file__).resolve().parents[2] / 'bin/oninix-desktop'
spec = importlib.util.spec_from_loader('desktop', importlib.machinery.SourceFileLoader('desktop', str(PATH)))
desktop = importlib.util.module_from_spec(spec)
spec.loader.exec_module(desktop)

@unittest.skipUnless(hasattr(desktop, "game_closed"), "requires automatic Game mode")
class GameModeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        patcher = patch.object(desktop, 'runtime', return_value=Path(self.tmp.name))
        patcher.start()
        self.addCleanup(patcher.stop)

    def mode(self, value):
        (Path(self.tmp.name) / 'mode.json').write_text(json.dumps(value))

    def test_call_mode_only_offers(self):
        self.mode({'name': 'call'})
        with patch.object(desktop, 'profile') as profile, patch.object(desktop, 'game_offer') as offer:
            desktop.game_started()
        profile.assert_not_called()
        offer.assert_called_once()

    def test_switches_and_remembers_previous_mode(self):
        self.mode({'name': 'work'})
        calls = []

        def enter(name, expect=None, auto=None):
            calls.append((name, expect({'name': 'work'}), expect({'name': 'call'}), auto['from']))
            self.mode({'name': name, 'auto': auto})
            return True
        with patch.object(desktop, 'profile', side_effect=enter), patch.object(desktop, 'run'), \
                patch.object(desktop, 'games_running', return_value=True):
            desktop.game_started()

        self.assertEqual(calls, [('game', True, False, 'work')])

    def test_unreadable_list_under_the_lock_keeps_waiting(self):
        self.mode({'name': 'game', 'auto': {'from': 'work', 'at': 1}})
        tries = []

        def profile(name, expect=None, auto=None):
            tries.append(name)
            if len(tries) == 2:
                self.mode({'name': 'work'})
                return True
            return False
        with patch.object(desktop, 'GAME_QUIET_SECONDS', 0), patch.object(desktop, 'profile', side_effect=profile), \
                patch.object(desktop, 'games_running', return_value=False), patch.object(desktop.time, 'sleep'):
            desktop.game_closed()
        self.assertEqual(tries, ['work', 'work'])

    def test_game_gone_at_once_returns(self):
        self.mode({'name': 'work'})

        def enter(name, expect=None, auto=None):
            if name == 'game':
                self.mode({'name': 'game', 'auto': auto})
            return True
        with patch.object(desktop, 'profile', side_effect=enter) as profile, patch.object(desktop, 'run'), \
                patch.object(desktop, 'GAME_QUIET_SECONDS', 0), patch.object(desktop, 'games_running', return_value=False):
            desktop.game_started()
        self.assertEqual([c.args[0] for c in profile.call_args_list], ['game', 'work'])

    def test_unknown_window_list_is_not_quiet(self):

        self.mode({'name': 'game', 'auto': {'from': 'work', 'at': 1}})
        answers = iter([False, None, False, None])

        def running():
            value = next(answers, 'stop')
            if value == 'stop':
                self.mode({'name': 'work'})
                return False
            return value
        clock = iter(range(0, 100, 3))
        with patch.object(desktop, 'profile') as profile, patch.object(desktop, 'games_running', side_effect=running), \
                patch.object(desktop.time, 'sleep'), patch.object(desktop.time, 'monotonic', side_effect=lambda: next(clock)):
            desktop.game_closed()
        profile.assert_not_called()

    def test_first_format_is_still_returned(self):
        self.mode({'name': 'game', 'auto_from': 'music'})
        with patch.object(desktop, 'GAME_QUIET_SECONDS', 0), patch.object(desktop, 'profile') as profile, \
                patch.object(desktop, 'games_running', return_value=False):
            desktop.game_closed()
        self.assertEqual(profile.call_args.args, ('music',))

    def test_last_moment_game_cancels_the_return(self):
        self.mode({'name': 'game', 'auto': {'from': 'work', 'at': 1}})
        with patch.object(desktop, 'GAME_QUIET_SECONDS', 0), patch.object(desktop, 'profile') as profile, \
                patch.object(desktop, 'games_running', return_value=False):
            desktop.game_closed()
        expect = profile.call_args.kwargs['expect']
        with patch.object(desktop, 'games_running', return_value=True):
            self.assertFalse(expect({'name': 'game', 'auto': {'from': 'work', 'at': 1}}))

    def test_hyprctl_failure_reads_as_unknown(self):
        failed = desktop.subprocess.CompletedProcess([], 1, '', 'error')
        with patch.object(desktop.subprocess, 'run', return_value=failed):
            self.assertIsNone(desktop.games_running())

    def test_manual_game_mode_stays_on(self):
        self.mode({'name': 'game'})
        with patch.object(desktop, 'profile') as profile, patch.object(desktop, 'games_running', return_value=False):
            desktop.game_closed()
        profile.assert_not_called()

    def test_returns_after_quiet_period(self):
        self.mode({'name': 'game', 'auto': {'from': 'music', 'at': 1}})
        with patch.object(desktop, 'GAME_QUIET_SECONDS', 0), patch.object(desktop, 'profile') as profile, \
                patch.object(desktop, 'games_running', return_value=False):
            desktop.game_closed()
        self.assertEqual(profile.call_args.args, ('music',))
        expect = profile.call_args.kwargs['expect']
        with patch.object(desktop, 'games_running', return_value=False):
            self.assertTrue(expect({'name': 'game', 'auto': {'from': 'music', 'at': 1}}))
            self.assertFalse(expect({'name': 'call'}))

    def test_game_still_running_keeps_mode(self):
        self.mode({'name': 'game', 'auto': {'from': 'normal', 'at': 1}})
        with patch.object(desktop, 'GAME_QUIET_SECONDS', 0), patch.object(desktop, 'profile') as profile, \
                patch.object(desktop, 'games_running', return_value=True):
            desktop.game_closed()
        profile.assert_not_called()

    def test_offer_expires_and_is_dismissed(self):
        self.mode({'name': 'call', 'since': 10})
        timeout = desktop.subprocess.TimeoutExpired('notify-send', 1, output=b'42\n')
        with patch.object(desktop.subprocess, 'run', side_effect=timeout), \
                patch.object(desktop, 'run') as run, patch.object(desktop, 'profile') as profile:
            desktop.game_offer('game', call_session=('call', 10))
        profile.assert_not_called()
        run.assert_called_once_with(['makoctl', 'dismiss', '-n', '42'])
