from pathlib import Path
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

LIB = Path(__file__).resolve().parents[2] / 'lib'
sys.path.insert(0, str(LIB))
import oninix_meetings as m

class MeetingTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.vault = self.root / 'vault'
        (self.vault / '.obsidian').mkdir(parents=True)
        self.patches = [patch.object(m, 'STATE', self.root / 'state'), patch.object(m, 'CONFIG', self.root / 'config.json'), patch.object(m, 'CACHE', self.root / 'cache'), patch.object(m, 'vault', return_value=self.vault)]
        for p in self.patches:
            p.start()
        m.STATE.mkdir()
        self.manager = m.Meetings.__new__(m.Meetings)
        self.manager.lock = threading.RLock()
        self.manager.processing = None
        self.manager.capture = None
        self.manager.processes = []
        self.manager.cancel = threading.Event()
        self.manager.wake = threading.Event()
        self.manager.download = {}
        self.manager.device_cache = []
        self.manager.device_time = time.monotonic()

    def tearDown(self):
        for p in reversed(self.patches):
            p.stop()
        self.tmp.cleanup()

    def job(self, state='ready'):
        job = dict(id='a'*32, title='Test meeting', created='2026-11-03T12:00:00+00:00', started=time.time(), duration=65, state=state, settings=m.preferences(), segments=[], sources={'output':'sink'})
        self.manager.save(job)
        m.atomic(self.manager.folder(job) / 'transcript.txt', '[00:00:12] Meeting audio: I will send the report tomorrow.\n')
        return job

    @unittest.skipUnless(hasattr(m, "clean_segments"), "requires the updated meeting backend")
    def test_repetition_loop_is_dropped_and_fragments_are_joined(self):
        loop = [dict(start=100 + i, end=101 + i, source='Microphone', text='How do you say that?') for i in range(50)]
        speech = [dict(start=10, end=11, source='Meeting audio', text='Because the business'),
                  dict(start=11.5, end=12, source='Meeting audio', text='expects a seamless transition.'),
                  dict(start=12.2, end=13, source='Microphone', text='Yes.'),
                  dict(start=13.1, end=14, source='Meeting audio', text='Next topic.')]
        result = m.clean_segments(loop + speech)
        self.assertEqual([r['text'] for r in result], ['Because the business expects a seamless transition.', 'Yes.', 'Next topic.', 'How do you say that?'])

    def test_delete_is_rejected_and_preserves_meeting_files(self):
        job = self.job()
        self.manager.publish(job['id'])
        note = Path(self.manager.get(job['id'])['note'])
        with self.assertRaisesRegex(ValueError, r'^Unknown meeting action\.$'):
            self.manager.handle({'op': 'delete', 'id': job['id']})
        self.assertTrue((self.manager.folder(job) / 'transcript.txt').is_file())
        self.assertTrue(note.is_file())

    def test_status_does_not_send_transcript_or_summary_every_second(self):
        job = self.job(); job.update(summary={'private':'text'}, transcript='private')
        self.manager.save(job)
        result = self.manager.status()['jobs'][0]
        self.assertNotIn('summary', result)
        self.assertNotIn('transcript', result)
        self.assertIn('private', self.manager.get(job['id'])['transcript'])
