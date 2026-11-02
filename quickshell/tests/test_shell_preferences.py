import copy
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'dotfiles/.local/lib'))
import station_shell as shell
loader = importlib.machinery.SourceFileLoader('desktop_modes', str(ROOT / 'dotfiles/.local/bin/station-desktop'))
spec = importlib.util.spec_from_loader(loader.name, loader)
desktop = importlib.util.module_from_spec(spec)
loader.exec_module(desktop)

class PreferencesTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.env = patch.dict(os.environ, XDG_STATE_HOME=self.tmp.name, XDG_CONFIG_HOME=self.tmp.name + "/config")
        self.env.start(); self.addCleanup(self.env.stop)

    def call(self, action, value):
        return shell.dispatch([action, json.dumps(value)])

    def test_layout_is_complete_and_control_center_remains_reachable(self):
        for layout in ({'top': ['status'], 'bottom': [], 'hidden': []},
                       {'top': ['launchers', 'workspaces'], 'bottom': ['media', 'window', 'metrics'], 'hidden': ['status']},
                       {'top': ['launchers', 'workspaces', 'status'], 'bottom': ['media', 'window', 'metrics', 'status'], 'hidden': []}):
            with self.assertRaises(ValueError):
                self.call('layout', {'role': 'primary', 'layout': layout})
        self.assertEqual(shell.preferences(), shell.DEFAULT)

    def test_roles_are_independent_and_undo_restores_layout(self):
        layout = {'top': ['media', 'workspaces', 'status'], 'bottom': ['window', 'metrics'], 'hidden': ['launchers']}
        self.call('layout', {'role': 'secondary', 'layout': layout})
        self.assertEqual(shell.preferences()['layouts']['primary'], shell.LAYOUT)
        self.assertEqual(shell.preferences()['layouts']['secondary'], layout)
        with patch.object(shell.subprocess, 'run'):
            self.call('undo', None)
        self.assertEqual(shell.preferences()['layouts']['secondary'], shell.LAYOUT)

    def test_favorites_and_navigation_survive_reload(self):
        self.call('favorites', ['mode:call', 'microphone', 'nightlight'])
        self.call('ui', {'last': 'audio', 'scroll': {'audio': .4}})
        self.assertEqual(shell.preferences()['favorites'], ['mode:call', 'microphone', 'nightlight'])
        self.assertEqual(shell.preferences()['ui']['scroll'], {'audio': .4})
        for bad in (['dnd', 'dnd'], ['shell-command'], 'audio'):
            with self.assertRaises(ValueError): self.call('favorites', bad)

    def test_presets_restore_all_files_without_touching_device_choices(self):
        self.call('devices', {'mode': 'call', 'sink': 'headset', 'source': 'mic'})
        shell.atomic(shell.state() / 'theme/name', 'graphite\n')
        shell.write(shell.state() / 'theme/shell.json', {'panelWidth': 92})
        expected = shell.snapshot()
        self.call('look-save', 'Evening')
        shell.atomic(shell.state() / 'theme/name', 'tesla-day\n')
        with patch.object(shell.subprocess, 'run'):
            self.call('look-apply', 'Evening')
        self.assertEqual(shell.snapshot(), expected)
        self.assertEqual(shell.data()['devices']['call']['sink'], 'headset')
        self.assertTrue(shell.data()['undo'])

    def test_invalid_preset_does_not_write_any_file(self):
        value = shell.snapshot(); value['files']['../../outside'] = 'bad'
        with self.assertRaises(ValueError): shell.apply_snapshot(value)
        self.assertFalse((shell.state() / 'theme').exists())

    def test_failed_apply_restores_before_image(self):
        self.call('look-save', 'Before')
        shell.atomic(shell.state() / 'theme/name', 'graphite\n')
        expected = shell.snapshot()
        with patch.object(shell.subprocess, 'run', side_effect=[RuntimeError('reload failed'), None, None]):
            with self.assertRaises(RuntimeError): self.call('look-apply', 'Before')
        self.assertEqual(shell.snapshot(), expected)

class ModesTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        env = patch.dict(os.environ, XDG_STATE_HOME=self.tmp.name, XDG_RUNTIME_DIR=self.tmp.name)
        env.start(); self.addCleanup(env.stop)
        self.audio = {'sink': None, 'source': 'unplugged-scarlett'}
        self.dnd = False
        self.night = True
        def command(args, **kwargs):
            if '--nightlight' in args: self.night = args[-1] == 'on'
            return b''
        for name, value in [('audio_defaults', lambda: (copy.deepcopy(self.audio), {'sink': {'speaker', 'headset'}, 'source': {'internal', 'mic'}})),
                            ('set_audio_default', lambda kind, name: self.audio.update({kind: name})),
                            ('modes', lambda: ['do-not-disturb'] if self.dnd else []),
                            ('nightlight', lambda: self.night),
                            ('set_dnd', lambda value: setattr(self, 'dnd', value)), ('run', command)]:
            p = patch.object(desktop, name, side_effect=value); p.start(); self.addCleanup(p.stop)
        shell.dispatch(['devices', json.dumps({'mode': 'call', 'sink': 'headset', 'source': 'mic'})])

    def test_normal_restores_absent_and_unplugged_preferences(self):
        desktop.profile('call'); self.assertEqual(self.audio, {'sink': 'headset', 'source': 'mic'})
        desktop.profile('normal')
        self.assertEqual(self.audio, {'sink': None, 'source': 'unplugged-scarlett'})
        self.assertFalse(self.dnd)

    def test_repeated_mode_does_not_replace_baseline(self):
        desktop.profile('call'); desktop.profile('call'); desktop.profile('game'); desktop.profile('normal')
        self.assertEqual(self.audio, {'sink': None, 'source': 'unplugged-scarlett'})
        self.assertTrue(self.night)

    def test_manual_choice_survives_normal(self):
        desktop.profile('call'); self.audio['sink'] = 'speaker'; desktop.profile('normal')
        self.assertEqual(self.audio['sink'], 'speaker')

    def test_unavailable_target_makes_no_changes(self):
        shell.dispatch(['devices', json.dumps({'mode': 'call', 'sink': 'missing', 'source': ''})])
        with self.assertRaises(ValueError): desktop.profile('call')
        self.assertFalse(self.dnd); self.assertTrue(self.night)
        self.assertEqual(self.audio['source'], 'unplugged-scarlett')
        self.assertFalse((desktop.runtime() / 'mode.json').exists())

    def test_mid_apply_failure_rolls_back_audio_and_settings(self):
        with patch.object(desktop, 'set_dnd', side_effect=[RuntimeError('failed'), None]):
            with self.assertRaises(RuntimeError): desktop.profile('call')
        self.assertEqual(self.audio, {'sink': None, 'source': 'unplugged-scarlett'})
        self.assertFalse((desktop.runtime() / 'mode.json').exists())

if __name__ == '__main__': unittest.main()
