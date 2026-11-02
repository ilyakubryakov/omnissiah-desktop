import importlib.machinery
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

class RecordingEncoder(unittest.TestCase):
    def setUp(self):
        runtime = tempfile.TemporaryDirectory()
        self.addCleanup(runtime.cleanup)
        source = Path(__file__).resolve().parents[1] / 'dotfiles/.local/bin/station-record'
        loader = importlib.machinery.SourceFileLoader('recording', str(source))
        spec = importlib.util.spec_from_loader(loader.name, loader)
        self.recording = importlib.util.module_from_spec(spec)
        with patch.dict(os.environ, XDG_RUNTIME_DIR=runtime.name):
            loader.exec_module(self.recording)

    def test_prefers_mp4_when_encoders_exist(self):
        with patch.object(self.recording, 'output', return_value=' V..... libx264\n A..... aac\n V..... libvpx-vp9\n A..... libopus'):
            suffix, args = self.recording.encoding()
        self.assertEqual(suffix, 'mp4')
        self.assertIn('libx264', args)
        self.assertIn('aac', args)

    def test_fedora_uses_webm_with_compatible_audio(self):
        with patch.object(self.recording, 'output', return_value=' V..... libvpx-vp9\n A..... libopus\n A..... aac'):
            suffix, args = self.recording.encoding()
        self.assertEqual(suffix, 'webm')
        self.assertIn('libvpx-vp9', args)
        self.assertIn('libopus', args)
        self.assertNotIn('aac', args)

    def test_missing_encoders_fail_before_capture(self):
        with patch.object(self.recording, 'output', return_value=' A..... aac'):
            with self.assertRaisesRegex(RuntimeError, 'No supported recording encoder'):
                self.recording.encoding()
