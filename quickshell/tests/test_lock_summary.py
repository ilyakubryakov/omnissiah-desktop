from datetime import datetime, timedelta
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / 'config/hypr/scripts/lock-summary'

class LockSummaryTest(unittest.TestCase):
    def run_with(self, events, ts=None):
        with tempfile.TemporaryDirectory() as home:
            (Path(home) / '.cache').mkdir()
            data = {'ts': time.time() if ts is None else ts, 'events': events}
            (Path(home) / '.cache/caldash.json').write_text(json.dumps(data))
            return subprocess.run([str(SCRIPT), 'meeting'], capture_output=True, text=True,
                                  env=dict(os.environ, HOME=home), check=True).stdout.strip()

    def setUp(self):

        if not 2 <= datetime.now().hour < 22:
            self.skipTest('too close to midnight')

    def event(self, start_min, end_min, title='Board <review> & budget', all_day=False):
        now = datetime.now().astimezone()
        return {'s': (now + timedelta(minutes=start_min)).isoformat(),
                'e': (now + timedelta(minutes=end_min)).isoformat(), 't': title, 'a': all_day}

    def test_title_never_shown_and_ongoing_wins(self):
        out = self.run_with([self.event(30, 60), self.event(-10, 20), self.event(-60, 600, all_day=True)])
        self.assertTrue(out.startswith('Meeting now · until '), out)
        self.assertNotIn('Board', out)

    def test_next_meeting_and_stale_cache(self):
        events = [self.event(25, 55)]
        self.assertRegex(self.run_with(events), r'^Next meeting \d\d:\d\d · in 2[45] min$')
        self.assertEqual(self.run_with(events, ts=time.time() - 7200), '')

if __name__ == '__main__':
    unittest.main()
