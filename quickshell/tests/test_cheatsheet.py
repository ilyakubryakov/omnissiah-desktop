import importlib.machinery
import importlib.util
from pathlib import Path
import os
from types import SimpleNamespace
import unittest
from unittest.mock import patch

loader = importlib.machinery.SourceFileLoader('cheatsheet', str(Path(__file__).resolve().parents[2] / 'dotfiles/.local/bin/cheatsheet-helper'))
spec = importlib.util.spec_from_loader(loader.name, loader)
sheet = importlib.util.module_from_spec(spec)
loader.exec_module(sheet)

def bind(key, description, mask=64, **extra):
    return {'key': key, 'description': description, 'modmask': mask, **extra}

class CheatSheetTest(unittest.TestCase):
    def test_missing_instance_is_resolved_only_for_this_wayland_display(self):
        replies = [SimpleNamespace(stdout='[{"instance":"other","wl_socket":"wayland-0"},{"instance":"ours","wl_socket":"wayland-1"}]'),
                   SimpleNamespace(stdout='[{"description":"terminal","modmask":64,"key":"Return"}]', returncode=0)]
        with patch.dict(os.environ, {'WAYLAND_DISPLAY':'wayland-1','HYPRLAND_INSTANCE_SIGNATURE':''}), patch.object(sheet.subprocess, 'run', side_effect=replies) as run:
            self.assertEqual(sheet.hyprland_shortcuts()[0]['keys'], 'Meta+Return')
            self.assertEqual(run.call_args.args[0], ['hyprctl','-i','ours','binds','-j'])
        with patch.dict(os.environ, {'WAYLAND_DISPLAY':'wayland-2','HYPRLAND_INSTANCE_SIGNATURE':''}), patch.object(sheet.subprocess, 'run', return_value=replies[0]):
            self.assertEqual(sheet.hyprland_shortcuts(), [])

    def test_remapping_updates_home_and_guides_instead_of_preserving_old_key(self):
        rows = sheet.hypr_rows([bind('F12', 'control center', 68), bind('Y', 'float / tile window'),
                                bind('space', 'float / tile the whole workspace', 65)])
        home = sheet.home_section([{'name': 'Hyprland', 'rows': rows}])
        self.assertEqual(next(r['keys'] for r in home if r['action'] == 'control center'), 'Meta+Ctrl+F12')
        floating = next(r for r in sheet.guides(rows) if r['desc'] == 'Three ways to float')
        self.assertIn('Meta+Y', floating['detail'])
        self.assertIn('Meta+Shift+Space', floating['detail'])
        self.assertNotIn('Meta+V', floating['detail'])

    def test_families_only_expand_when_all_registered_keys_have_the_description(self):
        rows = sheet.hypr_rows([bind(k, 'focus (arrows)') for k in ['left','right','up','down']])
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]['keys'], 'Meta+← ↑ ↓ →')
        partial = sheet.hypr_rows([bind('left', 'focus (arrows)'), bind('right', '')])
        self.assertEqual(partial[0]['keys'], 'Meta+Left')
        workspaces = sheet.hypr_rows([bind(str(k), 'go to workspace (1..0)') for k in range(10)])
        self.assertEqual(workspaces[0]['keys'], 'Meta+1…0')

    def test_unknown_actions_survive_and_release_callbacks_are_not_listed(self):
        rows = sheet.hypr_rows([bind('K', 'My new action', submap='edit'), bind('Alt_L', 'release', release=True), bind('Q', '')])
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]['desc'], 'My new action')
        self.assertIn('edit', rows[0]['detail'])

    def test_same_action_in_different_modifiers_and_submaps_is_not_merged(self):
        rows = sheet.hypr_rows([bind('Q', 'close window'), bind('Q', 'close window', 68), bind('Q', 'close window', submap='edit')])
        self.assertEqual(len(rows), 3)

if __name__ == '__main__':
    unittest.main()
