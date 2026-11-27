import importlib.machinery
import importlib.util
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]

def load(name, path):
    loader = importlib.machinery.SourceFileLoader(name, str(ROOT / path))
    module = importlib.util.module_from_spec(importlib.util.spec_from_loader(loader.name, loader))
    loader.exec_module(module)
    return module

doctor = load('doctor', 'bin/oninix-doctor')

@unittest.skipUnless(hasattr(doctor, 'crash_ack'), 'requires the updated Doctor')
class KernelTests(unittest.TestCase):
    def run_kernel(self, rows):
        out = '\n'.join(json.dumps({'__REALTIME_TIMESTAMP': str(int(ts * 1e6)), 'PRIORITY': str(prio), 'MESSAGE': msg})
                        for ts, prio, msg in rows)
        with patch.object(doctor, 'command', return_value=SimpleNamespace(returncode=0, stdout=out, stderr='')):
            return doctor.kernel()

    RESUME = [(100, 6, 'ACPI: PM: Waking up from system sleep state S3'), (102, 6, 'PM: suspend exit')]
    IDENTIFY = (113, 3, 'ata10.00: failed to IDENTIFY (I/O error, err_mask=0x4)')

    def test_spin_up_retry_after_sleep_is_ignored(self):
        level, message = self.run_kernel(self.RESUME + [self.IDENTIFY, (114, 6, 'ata10.00: configured for UDMA/133')])
        self.assertEqual(level, 'ok')
        self.assertIn('1 disk spin-up', message)

    def test_unrecovered_or_unrelated_errors_still_fail(self):
        self.assertEqual(self.run_kernel(self.RESUME + [self.IDENTIFY])[0], 'fail')
        self.assertEqual(self.run_kernel(self.RESUME + [self.IDENTIFY, (114, 6, 'ata9.00: configured for UDMA/133')])[0], 'fail')
        self.assertEqual(self.run_kernel([self.IDENTIFY, (114, 6, 'ata10.00: configured for UDMA/133')])[0], 'fail')
        self.assertEqual(self.run_kernel(self.RESUME + [(110, 3, 'nvme nvme0: I/O error')])[0], 'fail')

    def test_info_messages_are_not_errors(self):
        self.assertEqual(self.run_kernel([(1, 6, 'BTRFS info (device nvme2n1p2): first mount')])[0], 'ok')

@unittest.skipUnless(hasattr(doctor, 'crash_ack'), 'requires the updated Doctor')
class CrashTests(unittest.TestCase):
    SLICER_EXECUTABLES = ('/app/bin/orca-slicer', '/usr/bin/.bambu-studio-wrapped')

    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        patcher = patch.object(doctor, 'CRASH_ACK', Path(tmp.name) / 'ack')
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_corrupt_ack_reads_as_none(self):
        for text in ('inf', '9999999999999999.damaged', '99999999999999999999', '-5'):
            doctor.CRASH_ACK.write_text(text + '\n')
            self.assertEqual(doctor.crash_ack(), 0, text)

    def test_first_ack_format_in_seconds_still_counts(self):
        doctor.CRASH_ACK.write_text('1795695587\n')
        with patch.object(doctor.time, 'time_ns', return_value=1_795_700_000 * 10**9):
            self.assertEqual(doctor.crash_ack(), 1795695587 * 1_000_000)

    def dump(self, exe, at=1_795_000_000_750_000, sig=11, cmdline=""):
        return {'__REALTIME_TIMESTAMP': str(at), 'COREDUMP_EXE': exe,
                'COREDUMP_SIGNAL': str(sig), 'COREDUMP_CMDLINE': cmdline}

    def test_ack_boundary_is_exact(self):
        stamp = 1_795_000_000_750_000
        with patch.object(doctor.time, 'time_ns', return_value=stamp * 1000):
            doctor.ack_crashes()
            self.assertEqual(doctor.crash_summary(True, [self.dump('/bin/editor', at=stamp)])[0], 'ok')
            self.assertEqual(doctor.crash_summary(True, [self.dump('/bin/editor', at=stamp + 1)])[0], 'warn')

    def test_headless_browser_crashes_are_tooling(self):
        headless = self.dump('/bin/chrome', cmdline='/bin/chrome --headless=new --screenshot')
        normal = self.dump('/bin/chrome', cmdline='/bin/chrome --profile-directory=Test--headless')
        self.assertEqual(doctor.crash_summary(True, [headless])[0], 'ok')
        level, message = doctor.crash_summary(True, [headless, normal])
        self.assertEqual(level, 'warn')
        self.assertIn('chrome x1', message)

    def test_slicer_crashes_are_reported_in_the_summary(self):
        for exe in self.SLICER_EXECUTABLES:
            for sig in (6, 11):
                with self.subTest(exe=exe, sig=sig):
                    level, message = doctor.crash_summary(True, [self.dump(exe, sig=sig)])
                    self.assertEqual(level, 'warn')
                    self.assertIn(f'{Path(exe).name} x1', message)

    def test_slicer_crashes_are_warnings_in_the_timeline(self):
        from oninix_health import timeline
        with patch('oninix_health.journal', return_value=(True, [])):
            events = timeline([self.dump(exe) for exe in self.SLICER_EXECUTABLES])
        for exe in self.SLICER_EXECUTABLES:
            with self.subTest(exe=exe):
                self.assertIn(('warn', f'{Path(exe).name} crashed'), [(e['level'], e['text']) for e in events])
