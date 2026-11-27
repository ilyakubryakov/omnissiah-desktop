import importlib.machinery
import importlib.util
from datetime import timezone
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

DESKTOP = Path(__file__).resolve().parents[2] / 'desktop'
sys.path.insert(0, str(DESKTOP / 'lib'))

import oninix_calendar as calendar
import oninix_dictation as dictation
import oninix_health as health
import oninix_meetings as meetings
import oninix_notifications as notifications
import oninix_shell as shell


def load(name):
    loader = importlib.machinery.SourceFileLoader(name, str(DESKTOP / 'bin' / f'oninix-{name}'))
    spec = importlib.util.spec_from_loader(name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


desktop, doctor, keywatch = map(load, ('desktop', 'doctor', 'keywatch'))


class GameModeTests(unittest.TestCase):
    def setUp(self):
        temp = self.enterContext(tempfile.TemporaryDirectory())
        self.enterContext(patch.dict(os.environ, XDG_RUNTIME_DIR=temp))
        self.path = desktop.runtime() / 'mode.json'

    def test_automatic_entry_and_manual_override(self):
        self.path.write_text('{"name":"work"}')
        with patch.multiple(desktop, audio_defaults=lambda: (dict(sink=None, source=None), {}),
                            modes=lambda: [], nightlight=lambda: False, set_dnd=Mock(),
                            run=Mock(), game_closed=Mock()), patch.object(desktop.gaming, 'enter', return_value={}):
            desktop.action('game-started', [])
            state = desktop.read_json(self.path, {})
            self.assertEqual(state['name'], 'game')
            self.assertEqual(state['auto']['from'], 'work')
            desktop.action('mode', ['game'])
            self.assertIsNone(desktop.auto_of(desktop.read_json(self.path, {})))

    def test_call_offer_rechecks_session_and_game(self):
        self.path.write_text('{"name":"call","since":10}')
        result = subprocess.CompletedProcess([], 0, '123\ndefault\n', '')
        with patch.object(desktop.subprocess, 'run', return_value=result) as notify, \
                patch.object(desktop, 'profile') as profile, patch.object(desktop, 'game_closed') as closed:
            desktop.action('game-started', [])
        self.assertIn('--urgency=critical', notify.call_args.args[0])
        self.assertEqual(profile.call_args.args, ('game',))
        self.assertTrue(profile.call_args.kwargs['game_prompt'])
        self.assertTrue(profile.call_args.kwargs['expect']({'name': 'call', 'since': 10}))
        self.assertFalse(profile.call_args.kwargs['expect']({'name': 'call', 'since': 11}))
        closed.assert_called_once_with()

    def test_manual_game_exit_prompts_once_after_the_last_game(self):
        self.path.write_text('{"name":"game","since":10}')
        result = subprocess.CompletedProcess([], 0, '123\n', '')

        def notify_and_repeat_close(*args, **kwargs):
            desktop.game_closed()
            return result

        with patch.object(desktop, 'games_running', side_effect=[False] * 6), \
                patch.object(desktop.time, 'monotonic', side_effect=range(6)), \
                patch.object(desktop.time, 'sleep') as sleep, \
                patch.object(desktop.subprocess, 'run', side_effect=notify_and_repeat_close) as notify, \
                patch.object(desktop, 'profile') as profile, patch.object(desktop, 'run'):
            desktop.action('game-closed', [])
        self.assertEqual(sleep.call_count, 5)
        notify.assert_called_once()
        self.assertIn('--action=default=Return to Normal', notify.call_args.args[0])
        profile.assert_not_called()

    def test_unreadable_window_list_restarts_quiet_window(self):
        state = {'name': 'game', 'auto': {'from': 'music', 'at': 1}}
        self.path.write_text(json.dumps(state))
        with patch.object(desktop, 'games_running', side_effect=[False, None] + [False] * 7), \
                patch.object(desktop.time, 'monotonic', side_effect=range(8)), \
                patch.object(desktop.time, 'sleep') as sleep, \
                patch.object(desktop, 'profile', side_effect=lambda name, expect: expect(state)) as profile:
            desktop.action('game-closed', [])
        self.assertEqual(sleep.call_count, 7)
        self.assertEqual(profile.call_args.args, ('music',))


class DoctorTests(unittest.TestCase):
    def test_each_crash_uses_its_own_cmdline_and_signal(self):
        def crash(exe, signal=11, **fields):
            return {'COREDUMP_EXE': exe, 'COREDUMP_SIGNAL': str(signal),
                    '__REALTIME_TIMESTAMP': '1795000000000000', **fields}

        browser = crash('/nix/store/chromium/bin/.chromium-wrapped', COREDUMP_PID='7')
        headless = {**browser, 'COREDUMP_CMDLINE': '/chromium --headless=new'}
        interactive = {**browser, 'COREDUMP_CMDLINE': '/chromium "--profile-directory=work --headless"'}
        orca = crash('/app/bin/orca-slicer')
        abort = crash('/app/bin/orca-slicer', 6)
        bambu = crash('/nix/store/bambu/bin/.bambu-studio-wrapped')
        dev = crash(str(Path.home() / 'Projects/build/test'))
        self.assertEqual(health.tooling_crash(headless), 'headless browser')
        self.assertIsNone(health.tooling_crash(interactive))
        self.assertIsNone(health.known_crash(abort))
        with patch.object(doctor, 'crash_ack', return_value=0):
            level, summary = doctor.crash_summary(True, [headless, interactive, orca, abort, bambu, dev])
        self.assertEqual(level, 'warn')
        self.assertTrue(summary.startswith('2 recorded crashes'))
        with patch.object(health, 'journal', return_value=(True, [])):
            events = health.timeline([headless, interactive, orca, abort, bambu, dev])
        self.assertEqual([event['level'] for event in events if 'crashed' in event['text']],
                         ['warn', 'info', 'warn', 'info'])

    def test_acknowledgement_has_microsecond_boundary(self):
        temp = self.enterContext(tempfile.TemporaryDirectory())
        stamp = 1_795_000_000_123_456
        with patch.object(doctor, 'CRASH_ACK', Path(temp) / 'ack'), \
                patch.object(doctor.time, 'time_ns', return_value=stamp * 1000):
            doctor.ack_crashes()
            before = {'COREDUMP_COMM': 'app', '__REALTIME_TIMESTAMP': str(stamp)}
            after = {**before, '__REALTIME_TIMESTAMP': str(stamp + 1)}
            self.assertEqual(doctor.crash_summary(True, [before])[0], 'ok')
            self.assertTrue(doctor.crash_summary(True, [before, after])[1].startswith('1 recorded crashes'))

    def test_only_recovered_identify_retries_after_resume_are_ignored(self):
        wake = (100, 6, 'PM: suspend exit')
        identify = (113, 3, 'ata10.00: failed to IDENTIFY (I/O error, err_mask=0x4)')
        recovery = (114, 6, 'ata10.00: configured for UDMA/133')
        disk_error = (110, 3, 'ata10.00: I/O error reading a sector')
        for rows, boots, expected in [
            ([wake, identify, recovery], ['same'] * 3, 'ok'),
            ([wake, identify], ['same'] * 2, 'fail'),
            ([identify, recovery], ['same'] * 2, 'fail'),
            ([wake, disk_error, recovery], ['same'] * 3, 'fail'),
            ([wake, identify, recovery], ['previous', 'current', 'current'], 'fail'),
        ]:
            stdout = '\n'.join(json.dumps({'__REALTIME_TIMESTAMP': at * 1_000_000, 'PRIORITY': level,
                                           'MESSAGE': message, '_BOOT_ID': boot})
                               for (at, level, message), boot in zip(rows, boots))
            with self.subTest(rows=rows), patch.object(doctor, 'command',
                                                      return_value=subprocess.CompletedProcess([], 0, stdout, '')):
                self.assertEqual(doctor.kernel()[0], expected)


class VoiceAndSessionTests(unittest.TestCase):
    def test_calendar_exposes_supported_https_join_links(self):
        start = {'dateTime': '2026-11-27T10:00:00'}
        end = {'dateTime': '2026-11-27T10:30:00'}
        rows = calendar.normalized_microsoft(
            [dict(start=start, end=end, onlineMeeting={'joinUrl': 'https://teams.microsoft.com/l/meetup-join/123'})],
            'test', timezone.utc)
        self.assertTrue(rows[0]['m'])
        self.assertEqual(rows[0]['j'], 'https://teams.microsoft.com/l/meetup-join/123')
        bad = 'https://zoom.us.evil.example/ https://evil.example@zoom.us/ https://[broken'
        event = calendar.with_join({'m': False}, bad, 'See https://example.zoom.us/j/42?x=1&amp;y=2.')
        self.assertEqual(event['j'], 'https://example.zoom.us/j/42?x=1&y=2')
        self.assertNotIn('j', calendar.with_join({'m': False}, bad))

    def test_network_uses_a_physical_default_route_and_keeps_the_layer_fallback(self):
        details = r'''GENERAL.DEVICE:ether
GENERAL.TYPE:ethernet
GENERAL.STATE:100 (connected)
GENERAL.CONNECTION:Ethernet
GENERAL.DEVICE:wireless
GENERAL.TYPE:wifi
GENERAL.STATE:100 (connected)
GENERAL.CONNECTION:Wi\:Fi
IP6.ADDRESS[1]:2001\:db8\:\:2/64
GENERAL.DEVICE:tun
GENERAL.TYPE:tun
GENERAL.STATE:100 (connected)
'''
        ipv6 = json.dumps([{'dev': 'wireless', 'metric': 100, 'gateway': '2001:db8::1'}]).encode()
        with patch.object(desktop, 'run', side_effect=[details.encode(), b'[{"dev":"tun"}]', ipv6, b'full']):
            net = desktop.network_state()
        self.assertEqual(net['primary'], 'wireless')
        self.assertEqual(net['links'][0]['name'], 'Wi:Fi')
        self.assertEqual(net['links'][0]['address'], '2001:db8::2/64')
        fallback = {'manager': 'systemd-networkd', 'links': [{'device': 'eth0'}], 'connectivity': 'full'}
        with patch.object(desktop, 'networkmanager_state', side_effect=FileNotFoundError), \
                patch.object(desktop, 'system_network_state', return_value=fallback):
            net = desktop.network_state()
        self.assertEqual(net['manager'], 'systemd-networkd')
        self.assertEqual(net['primary'], 'eth0')
    def test_paste_shortcuts_use_the_window_class(self):
        for name, mods, key in [('Code', 'CTRL', 'code:55'), ('kitty', 'CTRL SHIFT', 'code:55'),
                                ('Emacs', 'SHIFT', 'code:118')]:
            self.assertEqual(dictation.paste_shortcut({'class': name}), (mods, key))

    def test_transcript_drops_loops_and_respects_interjections(self):
        def segment(start, end, source, text):
            return dict(start=start, end=end, source=source, text=text)

        rows = [segment(0, 1, 'Mic', 'First'), segment(1, 2, 'Mic', 'second'),
                segment(2, 3, 'Mic', 'Second!'), segment(3, 3.5, 'Output', 'Yes'),
                segment(3.5, 4, 'Mic', 'Next')]
        result = meetings.clean_segments(rows)
        self.assertEqual([row['text'] for row in result], ['First second', 'Yes', 'Next'])
        self.assertEqual(result[0]['end'], 2)

    def test_scroll_overshoot_and_unknown_pages(self):
        temp = self.enterContext(tempfile.TemporaryDirectory())
        with patch.dict(os.environ, XDG_STATE_HOME=temp):
            value = shell.dispatch(['ui', '{"last":"audio","scroll":{"audio":-0.01,"quick":1.1,"future":0.4}}'])
        self.assertEqual(value['prefs']['ui']['scroll'], {'audio': 0, 'quick': 1})

    def test_notification_marker_can_be_opened_without_touching_its_mtime(self):
        temp = self.enterContext(tempfile.TemporaryDirectory())
        with patch.dict(os.environ, XDG_RUNTIME_DIR=temp):
            notifications.update_marker()
            marker = Path(temp) / 'oninix-mako-notify'
            os.utime(marker, (123, 123))
            notifications.update_marker()
            self.assertEqual(marker.stat().st_mtime, 123)
            notifications.update_marker(changed=True)
            self.assertGreater(marker.stat().st_mtime, 123)


class KeywatchTests(unittest.TestCase):
    def test_printable_keys_are_anonymous_and_snapshots_are_private(self):
        temp = self.enterContext(tempfile.TemporaryDirectory())
        private = Path(temp) / 'keywatch'
        for code in (2, 16, 30, 44, 71):
            self.assertEqual(keywatch.classify(code), ('text', None))
            self.assertEqual(keywatch.held_name(code), 'char')
        with patch.object(keywatch, 'STATE', private):
            snapshot = keywatch.write_snapshot({'reason': 'test'})
        self.assertEqual(private.stat().st_mode & 0o777, 0o700)
        self.assertEqual(snapshot.stat().st_mode & 0o777, 0o600)

    def test_dumpable_process_refuses_to_open_devices(self):
        with patch.object(keywatch, 'not_dumpable', return_value=False), \
                patch.object(keywatch, 'keyboards') as keyboards, patch('sys.stderr'):
            self.assertEqual(keywatch.daemon(), 1)
        keyboards.assert_not_called()


if __name__ == '__main__':
    unittest.main()
