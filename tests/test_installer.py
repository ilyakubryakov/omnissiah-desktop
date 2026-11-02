import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
import subprocess
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('installer', ROOT / 'installer.py')
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)

class InstallLifecycle(unittest.TestCase):
    def setUp(self):
        self.settings = patch.object(installer, 'desktop_settings', return_value={})
        self.settings.start()
        self.addCleanup(self.settings.stop)
        self.temp = tempfile.TemporaryDirectory()
        self.home = Path(self.temp.name)
        self.state = self.home / '.local/state/omnissiah'
        self.data = self.home / '.local/share/omnissiah'

    def tearDown(self):
        self.temp.cleanup()

    def test_install_update_restore_keeps_original_and_later_edits(self):
        original = self.home / '.config/hypr/hyprland.conf'
        original.parent.mkdir(parents=True)
        original.write_bytes(b'original\x00configuration\n')
        installer.deploy(self.home, self.state, self.data)
        current = self.home / '.config/hypr'
        self.assertTrue(current.is_symlink())
        receipt = json.loads((self.state / 'receipt.json').read_text())
        self.assertEqual((Path(receipt['backup']) / '.config/hypr/hyprland.conf').read_bytes(), original.read_bytes() if original.exists() else b'original\x00configuration\n')
        pref = self.home / '.config/omnissiah/local.lua'
        pref.write_text('-- user preference\n')
        installer.deploy(self.home, self.state, self.data)
        self.assertEqual(pref.read_text(), '-- user preference\n')
        current.unlink()
        current.mkdir()
        (current / 'later.conf').write_text('later edits')
        installer.restore(self.home, self.state)
        self.assertEqual(original.read_bytes(), b'original\x00configuration\n')
        self.assertTrue(list((self.state / 'removed').glob('*/.config/hypr/later.conf')))
        self.assertEqual(pref.read_text(), '-- user preference\n')

    def test_broken_symlink_restored_without_following(self):
        link = self.home / '.config/hypr'
        link.parent.mkdir(parents=True)
        link.symlink_to('/nonexistent-original-config')
        installer.deploy(self.home, self.state, self.data)
        installer.restore(self.home, self.state)
        self.assertEqual(os.readlink(link), '/nonexistent-original-config')

    def test_update_refuses_locally_replaced_link_before_switching_release(self):
        installer.deploy(self.home, self.state, self.data)
        link = self.home / '.config/hypr'
        link.unlink(); link.mkdir(); (link / 'mine').write_text('keep')
        current = (self.data / 'current').resolve()

        extra = self.home / 'new.txt'; extra.write_text('next release')
        entries = list(installer.release_files()) + [(extra, Path('new.txt'))]
        with patch.object(installer, 'release_files', return_value=iter(entries)):
            with self.assertRaises(ValueError): installer.deploy(self.home, self.state, self.data)
        self.assertEqual((link / 'mine').read_text(), 'keep')
        self.assertEqual((self.data / 'current').resolve(), current)

    def test_native_manifests_and_unsupported_os(self):
        for name in installer.SUPPORTED:
            self.assertIn('hyprland', installer.manifest(name)['packages'])
            self.assertIn('quickshell', installer.manifest(name)['packages'])
            self.assertNotIn('nix', ' '.join(sum(installer.commands(name), [])))
        with patch.object(installer.platform, 'system', return_value='Darwin'):
            with self.assertRaises(ValueError): installer.distro()

        with patch.object(installer.platform, 'system', return_value='Linux'), patch.object(installer.platform, 'freedesktop_os_release', return_value={'ID': 'debian'}):
            with self.assertRaises(ValueError): installer.distro()

    def test_same_release_refuses_replaced_managed_path(self):
        installer.deploy(self.home, self.state, self.data)
        link = self.home / '.config/hypr'
        link.unlink()
        link.mkdir()
        (link / 'mine').write_text('keep')
        with self.assertRaises(ValueError):
            installer.deploy(self.home, self.state, self.data)
        self.assertEqual((link / 'mine').read_text(), 'keep')

    def test_palette_render_and_check(self):
        environment = {**os.environ, 'XDG_STATE_HOME': str(self.state)}
        theme = ROOT / 'dotfiles/.local/bin/theme'
        subprocess.run(['bash', str(theme), 'render-only'], env=environment, check=True, capture_output=True)
        subprocess.run(['bash', str(theme), 'check'], env=environment, check=True, capture_output=True)
        for palette in (ROOT / 'themes').glob('*/colors.toml'):
            output = palette.parent / 'out'
            value = json.loads((output / 'quickshell-colors.json').read_text())
            self.assertRegex(value['background'], r'^#[0-9a-fA-F]{6}$')
            self.assertIn('[Colors:Window]', (output / 'Station.colors').read_text())
            self.assertIn('background-color', (output / 'gtk.css').read_text())

if __name__ == '__main__': unittest.main()
