import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('icons', ROOT / 'themes/icons.py')
icons = importlib.util.module_from_spec(spec)
spec.loader.exec_module(icons)

class IconTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.mock = patch.multiple(icons, ROOTS=[self.root], DATA=[], STATE=self.root / 'state')
        self.mock.start()
        icons.theme_dirs.cache_clear(); icons.lookup.cache_clear()

    def tearDown(self):
        self.mock.stop(); self.tmp.cleanup()

    def theme(self, name, inherit='', files=()):
        target = self.root / name
        (target / 'scalable/apps').mkdir(parents=True)
        (target / 'index.theme').write_text('[Icon Theme]\nDirectories=scalable/apps\nInherits=' + inherit + '\n[scalable/apps]\nSize=48\nType=Scalable\n')
        for file in files:
            (target / 'scalable/apps' / (file + '.svg')).write_text('<svg/>')
        return target

    def test_selected_theme_beats_inherited_and_hicolor(self):
        base = self.theme('base', files=['folder', 'only-base'])
        selected = self.theme('selected', inherit='base', files=['folder'])
        app = self.theme('hicolor', files=['vendor-app'])
        self.assertEqual(icons.resolve('folder', 'selected'), (selected / 'scalable/apps/folder.svg').as_uri())
        self.assertEqual(icons.resolve('only-base', 'selected'), (base / 'scalable/apps/only-base.svg').as_uri())
        self.assertEqual(icons.resolve('vendor-app', 'selected'), (app / 'scalable/apps/vendor-app.svg').as_uri())

    def test_inheritance_cycle_and_missing_icons_terminate(self):
        self.theme('a', inherit='b'); self.theme('b', inherit='a')
        self.assertEqual(icons.resolve('absent', 'a'), '')
        self.assertEqual(icons.resolve('../outside', 'a'), '')

    def test_absolute_vendor_icon_and_spaces_in_path(self):
        icon = self.root / 'Vendor app.svg'; icon.write_text('<svg/>')
        self.assertEqual(icons.resolve(str(icon), 'absent'), icon.as_uri())

    def test_selection_is_independent_of_light_dark_palette(self):
        icons.select('fluent')
        self.assertEqual(icons.variant(icons.family(), False), 'Fluent-grey-light')
        self.assertEqual(icons.variant(icons.family(), True), 'Fluent-grey-dark')
        with self.assertRaises(ValueError): icons.select('../bad')
        self.assertEqual(icons.family(), 'fluent')

if __name__ == '__main__': unittest.main()
