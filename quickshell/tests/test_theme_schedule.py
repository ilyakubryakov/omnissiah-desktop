import contextlib
import datetime as dt
import importlib.machinery
import importlib.util
import io
from pathlib import Path
import tempfile
import tomllib
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
loader = importlib.machinery.SourceFileLoader("theme_schedule", str(ROOT / "dotfiles/.local/bin/theme-schedule"))
spec = importlib.util.spec_from_loader(loader.name, loader)
schedule = importlib.util.module_from_spec(spec)
loader.exec_module(schedule)

class ScheduleTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.paths = patch.multiple(schedule, CONFIG=self.root / "schedule.conf", CURRENT=self.root / "name",
                                    STATE_DIR=self.root, OVERRIDE=self.root / "override", NIGHTLIGHT=self.root / "nightlight")
        self.paths.start()

    def tearDown(self):
        self.paths.stop()
        self.tmp.cleanup()

    def cli(self, *args):
        with patch("sys.argv", ["theme-schedule", *args]), contextlib.redirect_stdout(io.StringIO()):
            schedule.main()

    def test_old_profile_keeps_existing_pair(self):
        schedule.CONFIG.write_text("mode=manual\nlight_at=08:00\n")
        cfg = schedule.load()
        self.assertEqual((cfg["light_palette"], cfg["dark_palette"]), ("kanagawa-lotus", "omnissiah"))
        self.assertEqual(cfg["light_at"], "08:00")

    def test_invalid_or_wrong_mode_stored_palette_falls_back(self):
        schedule.CONFIG.write_text("light_palette=../../private\ndark_palette=tesla-day\n")
        cfg = schedule.load()
        self.assertEqual(cfg["light_palette"], "kanagawa-lotus")
        self.assertEqual(cfg["dark_palette"], "omnissiah")
        for args in [("light", "tesla-night"), ("dark", "tesla-day"), ("dark", "missing"), ("light", "../tesla-day")]:
            before = schedule.CONFIG.read_bytes()
            with self.assertRaises(SystemExit): self.cli("--palette", *args)
            self.assertEqual(schedule.CONFIG.read_bytes(), before)

    def test_manual_pair_selection_does_not_change_theme_or_mode(self):
        schedule.CURRENT.write_text("graphite")
        with patch.object(schedule, "apply") as apply:
            self.cli("--palette", "light", "tesla-day")
            self.cli("--palette", "dark", "tesla-night")
        apply.assert_not_called()
        cfg = schedule.load()
        self.assertEqual(cfg["mode"], "manual")
        self.assertEqual(cfg["light_palette"], "tesla-day")
        self.assertEqual(cfg["dark_palette"], "tesla-night")
        self.assertEqual(schedule.CURRENT.read_text(), "graphite")

    def test_fixed_schedule_uses_pair_at_both_boundaries(self):
        cfg = dict(schedule.DEFAULTS, mode="fixed", light_palette="tesla-day", dark_palette="tesla-night")
        for hour, minute, expected in [(7, 29, "tesla-night"), (7, 30, "tesla-day"), (19, 29, "tesla-day"), (19, 30, "tesla-night")]:
            now = dt.datetime(2026, 10, 30, hour, minute).astimezone()
            self.assertEqual(schedule.scheduled_variant(cfg, now), expected)
            status = schedule.status(cfg, now)
            self.assertEqual(status["scheduled"], "light" if expected == "tesla-day" else "dark")

    def test_sun_schedule_uses_selected_pair(self):
        now = dt.datetime.now().astimezone()
        cfg = dict(schedule.DEFAULTS, mode="sun", light_palette="tesla-day", dark_palette="tesla-night")
        with patch.object(schedule, "sun_times", return_value=(now - dt.timedelta(hours=1), now + dt.timedelta(hours=1))):
            self.assertEqual(schedule.scheduled_variant(cfg, now), "tesla-day")

    def test_toggle_uses_mode_for_unpaired_current_theme(self):
        schedule.save(dict(schedule.DEFAULTS, light_palette="tesla-day", dark_palette="tesla-night"))
        for current, expected in [("graphite", "tesla-day"), ("tesla-day", "tesla-night"), ("kanagawa-lotus", "tesla-night")]:
            schedule.CURRENT.write_text(current)
            with patch.object(schedule, "apply") as apply: self.cli("--toggle")
            apply.assert_called_once_with(expected)

    def test_changing_auto_pair_reapplies_schedule_and_clears_hold(self):
        schedule.save(dict(schedule.DEFAULTS, mode="fixed"))
        schedule.OVERRIDE.write_text("hold")
        with patch.object(schedule, "scheduled_variant", return_value="tesla-night"), patch.object(schedule, "apply") as apply:
            self.cli("--palette", "dark", "tesla-night")
        apply.assert_called_once_with("tesla-night")
        self.assertFalse(schedule.OVERRIDE.exists())

class PaletteTest(unittest.TestCase):
    def test_tesla_text_and_selection_contrast(self):
        def luminance(hexcolor):
            rgb = [int(hexcolor[i:i+2], 16) / 255 for i in (1, 3, 5)]
            rgb = [v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in rgb]
            return sum(v * w for v, w in zip(rgb, (.2126, .7152, .0722)))
        def contrast(a, b):
            a, b = sorted((luminance(a), luminance(b)))
            return (b + .05) / (a + .05)
        for name in ("tesla-day", "tesla-night"):
            colors = tomllib.loads((ROOT / "themes" / name / "colors.toml").read_text())
            for surface in ("background", "window_background", "dark_background", "light_background"):
                for text in ("foreground", "muted", "dim_foreground", "accent"):
                    with self.subTest(palette=name, surface=surface, text=text):
                        self.assertGreaterEqual(contrast(colors[surface], colors[text]), 4.5)
            self.assertGreaterEqual(contrast(colors["accent"], colors["dark_background"]), 4.5)

if __name__ == "__main__": unittest.main()
