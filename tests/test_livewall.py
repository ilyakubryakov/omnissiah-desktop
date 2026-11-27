import importlib.machinery
import importlib.util
import json
from pathlib import Path
import tempfile
import types
import unittest
from unittest.mock import patch

loader = importlib.machinery.SourceFileLoader(
    'livewall', str(Path(__file__).resolve().parents[1] / 'desktop/bin/oninix-livewall'))
spec = importlib.util.spec_from_loader(loader.name, loader)
livewall = importlib.util.module_from_spec(spec)
loader.exec_module(livewall)

MONITORS = [
    {'id': 1, 'name': 'DP-3', 'dpmsStatus': True, 'x': 0, 'y': 0, 'width': 5120, 'height': 2160,
     'scale': 1.25, 'transform': 0, 'reserved': [0, 32, 0, 32],
     'activeWorkspace': {'id': 3, 'name': '3'}, 'specialWorkspace': {'name': ''}},
    {'id': 2, 'name': 'HDMI-A-1', 'dpmsStatus': True,
     'activeWorkspace': {'name': 'edge'}, 'specialWorkspace': {'name': ''}},
]

def client(ws, fullscreen=0, monitor=1, at=(100, 100), size=(800, 600), **extra):
    return dict({'monitor': monitor, 'workspace': {'name': ws}, 'fullscreen': fullscreen,
                 'mapped': True, 'hidden': False, 'at': list(at), 'size': list(size)}, **extra)

class PauseReason(unittest.TestCase):
    def test_plays_without_covering_windows(self):
        self.assertEqual(livewall.pause_reason(MONITORS, [client('3')], 'DP-3'), '')

    def test_maximized_on_visible_workspace(self):
        self.assertEqual(livewall.pause_reason(MONITORS, [client('3', 1)], 'DP-3'), 'maximized')

    def test_fullscreen_wins(self):
        clients = [client('3', 1), client('3', 2)]
        self.assertEqual(livewall.pause_reason(MONITORS, clients, 'DP-3'), 'fullscreen')
        self.assertEqual(livewall.pause_reason(MONITORS, [client('3', 3)], 'DP-3'), 'fullscreen')

    def test_ignores_other_workspaces_monitors_and_hidden(self):
        clients = [client('5', 2), client('edge', 2, monitor=2), client('3', 2, hidden=True),
                   client('3', 1, mapped=False)]
        self.assertEqual(livewall.pause_reason(MONITORS, clients, 'DP-3'), '')

    def test_special_workspace_counts(self):
        monitors = json.loads(json.dumps(MONITORS))
        monitors[0]['specialWorkspace'] = {'name': 'special:term'}
        self.assertEqual(livewall.pause_reason(monitors, [client('special:term', 1)], 'DP-3'), 'maximized')

    def test_tiled_windows_covering_the_desk(self):
        halves = [client('3', at=(3, 35), size=(2042, 1658)), client('3', at=(2051, 35), size=(2042, 1658))]
        self.assertEqual(livewall.pause_reason(MONITORS, halves, 'DP-3'), 'covered')
        self.assertEqual(livewall.pause_reason(MONITORS, halves[:1], 'DP-3'), '')

    def test_overlapping_windows_counted_once(self):
        same = [client('3', at=(0, 32), size=(2048, 1664))] * 3
        self.assertEqual(livewall.pause_reason(MONITORS, same, 'DP-3'), '')

    def test_work_area_rotated_and_reserved(self):
        monitor = {'x': 10, 'y': 0, 'width': 2560, 'height': 720, 'scale': 1, 'transform': 1, 'reserved': [0, 30, 0, 0]}
        self.assertEqual(livewall.work_area(monitor), (10, 30, 730, 2560))

    def test_dpms_off_or_missing_output(self):
        monitors = json.loads(json.dumps(MONITORS))
        monitors[0]['dpmsStatus'] = False
        self.assertEqual(livewall.pause_reason(monitors, [], 'DP-3'), 'dpms')
        self.assertEqual(livewall.pause_reason(MONITORS, [], 'DP-9'), 'dpms')

class Library(unittest.TestCase):
    def item(self, project, files=()):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        folder = Path(tmp.name) / '42'
        folder.mkdir()
        for name in files:
            (folder / name).write_bytes(b'x')
        (folder / 'project.json').write_text(json.dumps(project), encoding='utf-8-sig')
        return livewall.project_item(folder)

    def test_video_item(self):
        item = self.item({'title': 'Rain', 'type': 'Video', 'file': 'rain.mp4', 'preview': 'p.gif',
                          'tags': ['Nature'], 'contentrating': 'Everyone'}, ['rain.mp4', 'p.gif'])
        self.assertEqual((item['id'], item['type'], item['supported'], item['rating']), ('42', 'video', True, 'Everyone'))
        self.assertTrue(item['preview'].endswith('p.gif'))

    def test_missing_video_and_application(self):
        self.assertFalse(self.item({'type': 'video', 'file': 'gone.mp4'})['supported'])
        app = self.item({'type': 'application'})
        self.assertFalse(app['supported'])
        self.assertIn('Linux', app['reason'])

    def test_paths_outside_the_item_are_refused(self):
        outside = tempfile.NamedTemporaryFile(suffix='.png')
        self.addCleanup(outside.close)
        item = self.item({'type': 'video', 'file': '../../etc/passwd', 'preview': outside.name})
        self.assertEqual((item['file'], item['preview'], item['supported']), ('', '', False))

    def test_bad_properties_do_not_break_status(self):
        item = self.item({'type': 'scene', 'general': {'properties': ['x']}})
        self.assertEqual(livewall.item_properties(item, {'properties': {}}), [])

    def test_broken_project(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        folder = Path(tmp.name)
        (folder / 'project.json').write_text('{')
        self.assertIsNone(livewall.project_item(folder))

    def test_vdf_paths(self):
        text = '"libraryfolders"\n{\n "0"\n {\n  "path"  "/home/u/.local/share/Steam"\n }\n "1" { "path" "/games/SteamLibrary" }\n}'
        self.assertEqual([str(p) for p in livewall.vdf_paths(text)], ['/home/u/.local/share/Steam', '/games/SteamLibrary'])

class Placement(unittest.TestCase):
    def test_defaults_and_clamping(self):
        self.assertEqual(livewall.placement_of({'placement': {}}, '1'), {'fit': 'fill', 'x': 0.5, 'y': 0.5})
        config = {'placement': {'1': {'fit': 'fit', 'x': 2, 'y': 'bad'}, '2': {'fit': 'zoom'}}}
        self.assertEqual(livewall.placement_of(config, '1'), {'fit': 'fit', 'x': 1.0, 'y': 0.5})
        self.assertEqual(livewall.placement_of(config, '2')['fit'], 'fill')

class Still(unittest.TestCase):
    def test_fill_crops_like_the_renderer(self):
        f = livewall.still_filter((5120, 2160), {'fit': 'fill', 'x': 0.5, 'y': 0.0})
        self.assertIn('force_original_aspect_ratio=increase', f)
        self.assertTrue(f.endswith('crop=5120:2160:(iw-5120)*0.500:(ih-2160)*0.000'))

    def test_fit_pads(self):
        self.assertIn('pad=5120:2160', livewall.still_filter((5120, 2160), {'fit': 'fit', 'x': 0.5, 'y': 0.5}))

class Stop(unittest.TestCase):
    def test_stop_waits_for_the_whole_group(self):
        import subprocess as sp
        proc = sp.Popen(['sh', '-c', 'sh -c "trap : TERM; while :; do sleep 0.1; done" & wait'],
                        start_new_session=True)
        renderer = livewall.Renderer(dict(id='1', type='scene', path='/x', file='', preview=''), 'DP-3')
        renderer.proc = proc
        import time as _t
        _t.sleep(0.3)
        renderer.stop()
        self.assertFalse(livewall.group_alive(proc.pid))

class Capture(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.dir = Path(tmp.name)

    def run_capture(self, layers_after, cancel=False, before=None):
        target = self.dir / 'frame-1-5120x2160-fill-0.500-0.500-x.png'
        ours = [('linux-wallpaperengine', 4242)] if before is None else before

        class FakeRenderer:
            def __init__(self, *a, **k):
                self.proc = type('P', (), {'pid': 4242})()
            def start(self): pass
            def stop(self): pass
            def alive(self): return True

        def grim(argv, **kwargs):
            Path(argv[-1]).write_bytes(b'png')
            return livewall.subprocess.CompletedProcess(argv, 0)
        layers = iter([ours, layers_after])
        groups = {4242: 4242, 5555: 5555}
        with patch.object(livewall, 'Renderer', FakeRenderer), patch.object(livewall, 'CAPTURE_STAGING', self.dir / 'stage'), \
                patch.object(livewall, 'RUNTIME', self.dir / 'rt'), \
                patch.object(livewall.os, 'getpgid', side_effect=lambda pid: groups[pid]), \
                patch.object(livewall, 'CACHE', self.dir), patch.object(livewall, 'renderer_mapped', return_value=True), \
                patch.object(livewall, 'overlay_layers', side_effect=lambda o: next(layers)), \
                patch.object(livewall, 'screen_locked', return_value=False), patch.object(livewall, 'is_flat', return_value=False), \
                patch.object(livewall.subprocess, 'run', side_effect=grim), patch.object(livewall.time, 'sleep'):
            result = livewall.overlay_capture({'id': '1', 'type': 'scene'}, 'DP-3', {}, [], target, lambda: cancel)
        return result, target

    def test_clean_capture_becomes_the_frame(self):
        result, target = self.run_capture([('linux-wallpaperengine', 4242)])
        self.assertEqual(result, 'saved')
        self.assertTrue(target.exists())
        self.assertTrue(target.with_suffix('.captured').exists())
        self.assertEqual(list((self.dir / 'rt').glob('.capture-*')) + list((self.dir / 'stage').glob('.capture-*')), [])

    def test_notification_during_capture_discards_it(self):
        ok, target = self.run_capture([('linux-wallpaperengine', 4242), ('notifications', 99)])
        self.assertEqual(ok, 'failed')
        self.assertFalse(target.exists())
        self.assertEqual(list((self.dir / 'rt').glob('.capture-*')), [])

    def test_empty_overlay_or_foreign_surface_is_rejected(self):
        captured = []
        ok, _ = self.run_capture([], before=[])
        self.assertEqual(ok, 'failed')
        foreign = [('linux-wallpaperengine', 4242), ('linux-wallpaperengine', 5555)]
        ok, _ = self.run_capture(foreign, before=foreign)
        self.assertEqual(ok, 'failed')
        self.assertFalse((self.dir / 'rt').exists() and any((self.dir / 'rt').iterdir()))

    def test_cancelled_capture_writes_nothing(self):
        ok, target = self.run_capture([('linux-wallpaperengine', 4242)], cancel=True)
        self.assertEqual(ok, 'cancelled')
        self.assertFalse(target.exists())

class Flatness(unittest.TestCase):
    def stats(self, text):
        tmp = tempfile.NamedTemporaryFile(suffix='.png')
        self.addCleanup(tmp.close)
        done = livewall.subprocess.CompletedProcess([], 0, stdout=text)
        with patch.object(livewall.subprocess, 'run', return_value=done):
            return livewall.is_flat(Path(tmp.name))

    def test_equal_luma_different_colours_is_a_picture(self):
        text = ('lavfi.signalstats.YMIN=81\nlavfi.signalstats.YMAX=82\nlavfi.signalstats.UMIN=54\n'
                'lavfi.signalstats.UMAX=90\nlavfi.signalstats.VMIN=34\nlavfi.signalstats.VMAX=240\n')
        self.assertFalse(self.stats(text))

    def test_one_colour_is_flat_and_failure_is_not(self):
        flat = ('lavfi.signalstats.YMIN=14\nlavfi.signalstats.YMAX=18\nlavfi.signalstats.UMIN=127\n'
                'lavfi.signalstats.UMAX=129\nlavfi.signalstats.VMIN=127\nlavfi.signalstats.VMAX=129\n')
        self.assertTrue(self.stats(flat))
        self.assertIsNone(self.stats(''))

class Validation(unittest.TestCase):
    def test_order_must_be_finite(self):
        for value in ('NaN', 'inf', None, 'x', [1], 10 ** 400):
            self.assertEqual(livewall.order_of(value), 0.0)
        self.assertEqual(livewall.order_of('3'), 3.0)

    def test_frame_needs_a_complete_png_of_the_right_shape(self):
        import struct, zlib, os, time as _t

        def png(path, w, h, end=b'IEND', idat=True, rows=None, filter_byte=b'\0', bad_crc=False):
            ihdr = struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)

            def chunk(kind, data):
                crc = zlib.crc32(kind + data) ^ (1 if bad_crc and kind == b'IDAT' else 0)
                return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', crc)
            pixels = b''.join(filter_byte + bytes((x + y) % 256 for x in range(w * 3))
                              for y in range(h if rows is None else rows))
            body = chunk(b'IDAT', zlib.compress(pixels)) if idat else chunk(b'tEXt', b'x' * 64)
            path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', ihdr) + body + chunk(end, b''))
            os.utime(path, (_t.time() - 60, _t.time() - 60))
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        good, square, cut, empty, short, filt, crc = (Path(tmp.name) / f'frame-{n}-5120x2160-fill-0.5-0.5-x.png' for n in range(1, 8))
        png(good, 237, 100)
        png(square, 100, 100)
        png(cut, 237, 100, end=b'IDAT')
        png(empty, 237, 100, idat=False)
        png(short, 237, 100, rows=50)
        png(filt, 237, 100, filter_byte=b'\x09')
        png(crc, 237, 100, bad_crc=True)
        bad_header = Path(tmp.name) / 'frame-8-5120x2160-fill-0.5-0.5-x.png'
        png(bad_header, 237, 100)
        data = bytearray(bad_header.read_bytes())
        data[26] = 1
        bad_header.write_bytes(bytes(data))
        os.utime(bad_header, (_t.time() - 60, _t.time() - 60))
        self.assertFalse(livewall.frame_ready(bad_header))
        self.assertEqual([livewall.frame_ready(p) for p in (good, square, cut, empty, short, filt, crc)],
                         [True, False, False, False, False, False, False])
        black = Path(tmp.name) / 'frame-9-5120x2160-fill-0.5-0.5-x.png'
        ihdr = struct.pack('>IIBBBBB', 237, 100, 8, 2, 0, 0, 0)

        def chunk(kind, data):
            return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
        black.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', ihdr)
                          + chunk(b'IDAT', zlib.compress(b'\0' * (100 * (1 + 237 * 3)))) + chunk(b'IEND', b''))
        os.utime(black, (_t.time() - 60, _t.time() - 60))
        self.assertFalse(livewall.frame_ready(black))
        self.assertTrue(livewall.frame_failed(black))
        self.assertFalse(black.exists())

    def test_dark_but_real_frame_is_kept(self):
        import subprocess as sp
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        dark = Path(tmp.name) / 'frame-1-5120x2160-fill-0.5-0.5-x.png'
        sp.run(['ffmpeg', '-v', 'error', '-f', 'lavfi', '-i', 'gradients=s=474x200:c0=0x050505:c1=0x303030:n=2',
                '-frames:v', '1', '-pix_fmt', 'rgb24', str(dark)], check=True)
        self.assertFalse(livewall.is_flat(dark))

    def test_colors(self):
        self.assertTrue(livewall.valid_color('1 0.47 0'))
        for bad in ('2 . 9', '1 1', '1.5 0 0', '-1 0 0', 'a b c'):
            with self.subTest(bad=bad):
                self.assertFalse(livewall.valid_color(bad))

    def test_fit_ignores_offsets(self):
        self.assertEqual(livewall.effective({'fit': 'fit', 'x': 0.1, 'y': 0.9}), {'fit': 'fit', 'x': 0.5, 'y': 0.5})
        self.assertEqual(livewall.effective({'fit': 'fill', 'x': 0.1, 'y': 0.9})['y'], 0.9)

    def test_web_sandbox_cuts_network_home_runtime_and_bus(self):
        with patch.dict(livewall.os.environ, {'XDG_RUNTIME_DIR': '/run/user/7', 'WAYLAND_DISPLAY': 'wayland-1'}):
            argv = livewall.web_sandbox(['/games/a'], ['/cache'])
        for flag in ('--unshare-net', '--unshare-pid', '--unsetenv', 'dbus-run-session'):
            self.assertIn(flag, argv)
        tmpfs = [argv[i + 1] for i, a in enumerate(argv) if a == '--tmpfs']
        self.assertIn(str(livewall.HOME), tmpfs)
        self.assertIn('/run/user/7', tmpfs)
        self.assertEqual(argv[2:4], ['/', '/'])
        self.assertEqual(argv[0:2], ['bwrap', '--ro-bind'])
        self.assertIn('/run/user/7/wayland-1', argv)
        self.assertEqual(argv[argv.index('/cache') - 1], '--bind')

    def test_no_redirect_for_the_key(self):
        self.assertIsNone(livewall.NoRedirect().redirect_request(None, None, 302, 'Found', {}, 'https://evil.example/'))

class Query(unittest.TestCase):
    def args(self, **kw):
        base = dict(sort='trend', days=None, type=None, rating=None, tag=None, resolution=None,
                    search=None, cursor=None, per_page=None)
        base.update(kw)
        return types.SimpleNamespace(**base)

    def test_defaults_exclude_applications_and_adult(self):
        req = livewall.query_request(self.args())
        self.assertEqual(req['query_type'], 3)
        self.assertEqual(req['cursor'], '*')
        self.assertEqual(req['days'], 7)
        self.assertEqual(set(req['excludedtags']), {'Application', 'Questionable', 'Mature'})
        self.assertTrue(req['match_all_tags'])

    def test_types_by_exclusion_and_tags_required(self):
        req = livewall.query_request(self.args(sort='newest', type=['video', 'scene'], rating=['everyone', 'questionable'],
                                               tag=['Nature'], resolution='3840 x 2160'))
        self.assertEqual(req['query_type'], 1)
        self.assertEqual(set(req['excludedtags']), {'Web', 'Application', 'Mature'})
        self.assertEqual(req['requiredtags'], ['Nature', '3840 x 2160'])
        self.assertNotIn('days', req)

    def test_search_ranks_by_text(self):
        self.assertEqual(livewall.query_request(self.args(search='rain'))['query_type'], 12)
        self.assertEqual(livewall.query_request(self.args(sort='subscribed', search='rain'))['query_type'], 9)

    def test_unknown_sort(self):
        with self.assertRaises(livewall.Fail):
            livewall.query_request(self.args(sort='random'))


class LiveNeedsTheService(unittest.TestCase):
    def test_live_is_refused_without_the_service(self):
        args = livewall.argparse.Namespace(cmd='set', mode='live', item='7')
        with patch.object(livewall, 'service_installed', return_value=False), \
                patch.object(livewall, 'write_json') as write:
            with self.assertRaises(livewall.Fail):
                livewall.edit_config(args)
        write.assert_not_called()

if __name__ == '__main__':
    unittest.main()
