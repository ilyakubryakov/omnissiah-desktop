import importlib.machinery
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

loader = importlib.machinery.SourceFileLoader(
    'livewall_daemon', str(Path(__file__).resolve().parents[1] / 'desktop/bin/oninix-livewall'))
spec = importlib.util.spec_from_loader(loader.name, loader)
livewall = importlib.util.module_from_spec(spec)
loader.exec_module(livewall)

class FakeRenderer:
    instances = []
    fail_start = False
    pause_ok = True

    def __init__(self, item, output, placement=None, properties=(), frame=None):
        self.item, self.output = item, output
        self.placement, self.properties = placement, list(properties)
        self.paused, self.running, self.stopped = False, False, False
        self.pauses = []
        self.size = None
        self.unloaded = False
        self.frame = frame
        self.started_at, self.ran, self.settled = 0.0, 0.0, False
        self.paused_at = 0.0
        self.frame_play = 0.0
        self.proc = type('P', (), {'pid': 4242})()
        FakeRenderer.instances.append(self)

    def start(self):
        if FakeRenderer.fail_start:
            raise OSError('exec failed')
        if self.item['type'] != 'video' and not livewall.vram_allows_start():
            raise livewall.NoVram('Waiting for GPU memory')
        self.waiting_vram = False
        self.running = True
        self.started_at, self.ran, self.settled = livewall.time.monotonic(), 0.0, False

    def alive(self):
        return self.running or self.unloaded

    def configure(self, placement, properties):
        self.placement, self.properties = placement, list(properties)

    def pause(self, value):
        self.pauses.append(value)
        if not FakeRenderer.pause_ok:
            return False
        if value == self.paused:
            return True
        if not value and self.unloaded:
            try:
                self.start()
            except livewall.NoVram:
                self.waiting_vram = True
                return False
            self.unloaded = False
        self.paused = value
        self.paused_at = livewall.time.monotonic() if value else 0.0
        return True

    def unload(self):
        self.unloads = getattr(self, 'unloads', 0) + 1
        self.running, self.unloaded, self.paused = False, True, True

    def stop(self):
        self.running, self.stopped = False, True

    def yield_gpu(self):
        self.stop()
        self.unloaded, self.paused, self.waiting_vram = True, True, True

ITEM = {'id': '7', 'type': 'video', 'supported': True, 'reason': '', 'path': '/w/7', 'file': '/w/7/a.mp4', 'preview': ''}

class Daemon(unittest.TestCase):
    def setUp(self):
        FakeRenderer.instances, FakeRenderer.fail_start, FakeRenderer.pause_ok = [], False, True
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.config = {'mode': 'live', 'item': '7', 'placement': {}, 'properties': {}, 'broken': []}
        self.game, self.reason, self.stamp, self.mapped = False, '', 1.0, True
        self.wallpapers = []
        self.shown = None
        self.statuses = []
        self.still = Path(tmp.name) / 'still.png'
        self.gpu_free = None
        livewall.STILL_FAILED.clear()
        livewall.CURRENT_RENDERER[0] = None

        def set_hyprpaper(output, path):
            if not path:
                return False
            self.wallpapers.append(str(path))
            self.shown = str(path)
            return True
        stat = type('S', (), {})
        patches = [
            patch.object(livewall, 'session_env', return_value=True),
            patch.object(livewall, 'hypr_events', side_effect=lambda: self.socket),
            patch.object(livewall.select, 'select', side_effect=self.select),
            patch.object(livewall, 'main_output', return_value='DP-3'),
            patch.object(livewall, 'read_config', side_effect=lambda: dict(self.config)),
            patch.object(livewall, 'CONFIG', type('C', (), {'stat': lambda _: setattr(stat, 'st_mtime', self.stamp) or stat})()),
            patch.object(livewall, 'find_item', side_effect=lambda i: dict(ITEM) if i == '7' else None),
            patch.object(livewall, 'game_mode', side_effect=lambda: self.game),
            patch.object(livewall, 'Renderer', FakeRenderer),
            patch.object(livewall, 'set_hyprpaper', side_effect=set_hyprpaper),
            patch.object(livewall, 'CACHE', Path(tmp.name) / 'cache'),
            patch.object(livewall, 'hyprpaper_shows', side_effect=lambda output: self.shown),
            patch.object(livewall, 'static_wallpaper', return_value='/static.png'),
            patch.object(livewall, 'still_frame', side_effect=lambda *a: self.still),
            patch.object(livewall, 'pause_reason', side_effect=lambda *a: self.reason),
            patch.object(livewall, 'hypr', return_value=[]),
            patch.object(livewall, 'screen_locked', return_value=False),
            patch.object(livewall, 'renderer_mapped', side_effect=lambda output, group: self.mapped),
            patch.object(livewall, 'gpu_measure', side_effect=lambda: ('none', None) if self.gpu_free is None
                         else ('unknown', None) if self.gpu_free == 'fail' else ('ok', self.gpu_free)),
            patch.dict(livewall.GPU, {'at': -1e9, 'status': 'unknown', 'free': None, 'hold_until': 0.0,
                                      'strikes': 0, 'last_strike': -1e9}),
            patch.object(livewall, 'write_json', side_effect=lambda path, data, *a: self.statuses.append(data)),
            patch.object(livewall.time, 'sleep'),
            patch('builtins.print'),
        ]
        test = self

        class Socket:
            def recv(self, size):
                if not test.pending:
                    raise BlockingIOError
                test.pending = False
                return b'configreloaded>>\n'

            def close(self):
                pass
        self.socket, self.pending = Socket(), False
        for p in patches:
            p.start()
            self.addCleanup(p.stop)

    def select(self, readers, *_):
        self.now += 1
        for action in self.schedule.pop(self.now, []):
            action()
        return (readers if self.pending else []), [], []

    def event(self):
        self.pending = True

    def drive(self, ticks, schedule=None):
        self.now, self.schedule = 0, dict(schedule or {})
        livewall._daemon_loop(ticks=ticks)

    def change(self, **values):
        self.config.update(values)
        self.stamp += 1

    def test_live_plays_over_its_still(self):
        self.drive(1)
        self.assertEqual(self.wallpapers, [str(self.still)])
        self.assertTrue(FakeRenderer.instances[0].running)
        self.assertEqual(self.statuses[-1]['state'], 'playing')

    def test_live_to_static_puts_the_static_wallpaper_back(self):
        self.drive(2, {2: [lambda: self.change(mode='static')]})
        self.assertTrue(FakeRenderer.instances[0].stopped)
        self.assertEqual(self.wallpapers, [str(self.still), '/static.png'])

    def test_game_mode_unloads_and_shows_static(self):
        self.drive(2, {2: [lambda: setattr(self, 'game', True)]})
        self.assertTrue(FakeRenderer.instances[0].stopped)
        self.assertEqual(self.wallpapers[-1], '/static.png')
        self.assertEqual(self.statuses[-1], {'state': 'unloaded', 'reason': 'game', 'error': '', 'output': 'DP-3'})

    def test_game_mode_during_the_still_prevents_the_start(self):
        def still(*a):
            self.game = True
            return self.still
        with patch.object(livewall, 'still_frame', side_effect=still):
            self.drive(1)
        self.assertEqual(FakeRenderer.instances, [])
        self.assertEqual(self.statuses[-1]['state'], 'unloaded')

    def test_crashed_renderer_restarts_then_backs_off(self):
        crash = lambda: setattr(FakeRenderer.instances[-1], 'running', False)
        self.drive(4, {2: [crash], 3: [crash], 4: [crash]})
        self.assertEqual(len(FakeRenderer.instances), 3)
        self.assertEqual(self.statuses[-1]['state'], 'error')
        self.assertEqual(self.wallpapers[-1], '/static.png')

    def test_failed_start_reports_and_shows_static(self):
        FakeRenderer.fail_start = True
        self.drive(1)
        self.assertEqual(self.statuses[-1]['state'], 'error')
        self.assertIn('exec failed', self.statuses[-1]['error'])
        self.assertEqual(self.wallpapers[-1], '/static.png')

    def test_new_renderer_plays_until_mapped_then_pauses(self):
        self.reason, self.mapped = 'covered', False
        clock = {'now': 100.0}
        with patch.object(livewall.time, 'monotonic', side_effect=lambda: clock['now']):
            self.drive(4, {2: [lambda: clock.update(now=103.0)],
                           3: [lambda: self.__setattr__('mapped', True)]})
        self.assertEqual(FakeRenderer.instances[0].pauses[:2], [False, False])
        self.assertEqual(FakeRenderer.instances[0].pauses[-1], True)
        self.assertEqual(self.statuses[-1]['state'], 'paused')

    def test_scene_waits_for_gpu_memory_on_its_still(self):
        scene = dict(ITEM, type='scene', file='')
        self.gpu_free = 3400
        freed = lambda: setattr(self, 'gpu_free', 10000)
        clock = {'now': 100.0}
        tick = lambda: clock.update(now=clock['now'] + 3.0)
        with patch.object(livewall, 'find_item', side_effect=lambda i: dict(scene)), \
                patch.object(livewall, 'frame_path', return_value=Path('/cache/frame.png')), \
                patch.object(livewall, 'frame_ready', return_value=True), \
                patch.object(livewall.time, 'monotonic', side_effect=lambda: clock['now']):
            self.drive(4, {2: [tick], 3: [tick, freed], 4: [tick]})
        states = [(st['state'], st['reason']) for st in self.statuses]
        self.assertIn(('waiting', 'gpu'), states)
        self.assertEqual(self.wallpapers, ['/cache/frame.png'])
        self.assertTrue(FakeRenderer.instances[-1].running)
        self.assertEqual(self.statuses[-1]['error'], '')

    def test_scene_dying_short_of_memory_waits_with_a_hold(self):
        scene = dict(ITEM, type='scene', file='')
        self.gpu_free = 9000
        clock = {'now': 100.0}
        step = lambda s: (lambda: clock.update(now=clock['now'] + s))
        def crash():
            FakeRenderer.instances[-1].running = False
            self.gpu_free = 700
        freed = lambda: setattr(self, 'gpu_free', 9000)
        with patch.object(livewall, 'find_item', side_effect=lambda i: dict(scene)), \
                patch.object(livewall, 'frame_path', return_value=Path('/cache/frame.png')), \
                patch.object(livewall, 'frame_ready', return_value=True), \
                patch.object(livewall.time, 'monotonic', side_effect=lambda: clock['now']):
            self.drive(4, {2: [step(3), crash], 3: [step(3), freed], 4: [step(3)]})
        self.assertFalse(any(r.running for r in FakeRenderer.instances))
        self.assertEqual(self.statuses[-1]['state'], 'waiting')
        self.assertNotIn('keeps crashing', self.statuses[-1]['error'])

    def test_unknown_gpu_memory_does_not_start_blind(self):
        scene = dict(ITEM, type='scene', file='')
        self.gpu_free = 'fail'
        with patch.object(livewall, 'find_item', side_effect=lambda i: dict(scene)), \
                patch.object(livewall, 'frame_path', return_value=Path('/cache/frame.png')), \
                patch.object(livewall, 'frame_ready', return_value=True):
            self.drive(2)
        self.assertFalse(any(r.running for r in FakeRenderer.instances))
        self.assertEqual(self.statuses[-1]['state'], 'waiting')

    def test_running_scene_yields_the_gpu_holds_then_comes_back(self):
        scene = dict(ITEM, type='scene', file='')
        self.gpu_free = 9000
        clock = {'now': 100.0}
        step = lambda s: (lambda: clock.update(now=clock['now'] + s))
        low = lambda: setattr(self, 'gpu_free', 600)
        freed = lambda: setattr(self, 'gpu_free', 9000)
        with patch.object(livewall, 'find_item', side_effect=lambda i: dict(scene)), \
                patch.object(livewall, 'frame_path', return_value=Path('/cache/frame.png')), \
                patch.object(livewall, 'frame_ready', return_value=True), \
                patch.object(livewall.time, 'monotonic', side_effect=lambda: clock['now']):
            self.drive(5, {2: [step(31), low], 3: [step(5), freed], 4: [step(5)], 5: [step(61)]})
        r = FakeRenderer.instances[0]
        self.assertTrue(r.running)
        self.assertEqual(len(FakeRenderer.instances), 1)
        waits = [st['state'] for st in self.statuses]
        self.assertIn('waiting', waits)
        self.assertNotIn('/static.png', self.wallpapers)

    def test_scene_waits_for_its_frame_but_not_forever(self):
        scene = dict(ITEM, type='scene', file='')
        self.reason = 'covered'
        clock = {'now': 100.0}
        with patch.object(livewall, 'find_item', side_effect=lambda i: dict(scene)), \
                patch.object(livewall, 'frame_path', return_value=Path('/cache/frame.png')), \
                patch.object(livewall, 'frame_ready', return_value=False), \
                patch.object(livewall.time, 'monotonic', side_effect=lambda: clock['now']):
            tick = lambda: clock.update(now=clock['now'] + 1.0)
            with patch('builtins.print') as log:
                self.drive(20, {n: [tick] for n in range(2, 21)})
        pauses = FakeRenderer.instances[0].pauses
        self.assertEqual(pauses[:10], [False] * 10)
        self.assertEqual(pauses[-1], True)
        self.assertTrue(any('without its frame' in str(c) for c in log.call_args_list))

    def test_lock_outranks_covered_and_skips_the_grace(self):
        self.reason, self.mapped = 'covered', False
        with patch.object(livewall, 'screen_locked', return_value=True):
            self.drive(1)
        self.assertEqual(FakeRenderer.instances[0].pauses, [True])
        self.assertEqual(self.statuses[-1]['reason'], 'locked')

    def test_settled_grace_does_not_reopen(self):
        self.reason = 'maximized'
        clock = {'now': 100.0}
        with patch.object(livewall.time, 'monotonic', side_effect=lambda: clock['now']):
            self.drive(4, {2: [lambda: clock.update(now=102.0)],
                           3: [lambda: clock.update(now=103.0), lambda: setattr(self, 'mapped', None), self.event],
                           4: [lambda: clock.update(now=104.0), self.event]})
        pauses = FakeRenderer.instances[0].pauses
        self.assertEqual(pauses[-2:], [True, True])

    def test_paused_time_does_not_count_toward_the_grace(self):
        self.reason, self.mapped = 'dpms', False
        clock = {'now': 100.0}
        with patch.object(livewall.time, 'monotonic', side_effect=lambda: clock['now']):
            self.drive(3, {2: [lambda: clock.update(now=120.0)],
                           3: [lambda: clock.update(now=121.0), lambda: setattr(self, 'reason', 'covered'), self.event]})
        self.assertEqual(FakeRenderer.instances[0].pauses[-1], False)

    def test_long_paused_scene_is_unloaded_and_comes_back(self):
        scene = dict(ITEM, type='scene', file='')
        self.reason = 'locked'
        clock = {'now': 100.0}
        with patch.object(livewall, 'find_item', side_effect=lambda i: dict(scene)), \
                patch.object(livewall.time, 'monotonic', side_effect=lambda: clock['now']):
            self.drive(4, {2: [lambda: clock.update(now=200.0), self.event],
                           3: [lambda: clock.update(now=500.0), self.event],
                           4: [lambda: clock.update(now=501.0), lambda: setattr(self, 'reason', ''), self.event]})
        renderer = FakeRenderer.instances[0]
        self.assertEqual(getattr(renderer, 'unloads', 0), 1)
        self.assertTrue(renderer.running)
        self.assertEqual(self.statuses[-1]['state'], 'playing')

    def unload_at_tick_2(self, **extra):
        def unload():
            renderer = FakeRenderer.instances[0]
            renderer.item = dict(ITEM, type='scene', file='')
            renderer.running, renderer.unloaded, renderer.paused = False, True, True
            for key, value in extra.items():
                setattr(renderer, key, value)
        return unload

    def test_failed_resume_is_a_start_failure_not_a_crash(self):
        def start_fails():
            raise livewall.Fail('Wallpaper Engine is not installed in Steam')
        self.drive(2, {2: [self.unload_at_tick_2(start=start_fails)]})
        self.assertEqual(self.statuses[-1]['state'], 'error')
        self.assertIn('not installed', self.statuses[-1]['error'])

    def test_unloaded_scene_stays_unloaded_in_game_mode(self):
        self.drive(2, {2: [self.unload_at_tick_2(), lambda: setattr(self, 'game', True)]})
        self.assertFalse(FakeRenderer.instances[0].running)

    def test_missing_frame_gets_one_start_under_covering_windows(self):
        with patch.object(livewall, 'frame_ready', return_value=False):
            self.drive(2, {2: [self.unload_at_tick_2(frame=Path('/cache/frame.png')),
                               lambda: setattr(self, 'reason', 'covered'), self.event]})
        renderer = FakeRenderer.instances[0]
        self.assertTrue(renderer.running)

    def test_missing_frame_start_is_bounded_and_scene_only(self):
        with patch.object(livewall, 'frame_ready', return_value=False):
            self.drive(2, {2: [self.unload_at_tick_2(frame=Path('/cache/frame.png'), frame_play=15.0),
                               lambda: setattr(self, 'reason', 'covered'), self.event]})
        self.assertFalse(FakeRenderer.instances[0].running)
        FakeRenderer.instances.clear()
        web = lambda: setattr(FakeRenderer.instances[0], 'item', dict(ITEM, type='web', file=''))
        with patch.object(livewall, 'frame_ready', return_value=False):
            self.drive(2, {2: [self.unload_at_tick_2(frame=Path('/cache/frame.png')), web,
                               lambda: setattr(self, 'reason', 'covered'), self.event]})
        self.assertFalse(FakeRenderer.instances[0].running)

    def test_video_is_never_unloaded_for_a_long_pause(self):
        self.reason = 'locked'
        clock = {'now': 100.0}
        with patch.object(livewall.time, 'monotonic', side_effect=lambda: clock['now']):
            self.drive(3, {2: [lambda: clock.update(now=1000.0), self.event]})
        self.assertEqual(getattr(FakeRenderer.instances[0], 'unloads', 0), 0)

    def test_empty_own_frame_is_captured_from_the_screen_once(self):
        scene = dict(ITEM, type='scene', file='')
        clock = {'now': 100.0}
        tick = lambda: clock.update(now=clock['now'] + 2.0)
        done = []
        with patch.object(livewall, 'find_item', side_effect=lambda i: dict(scene)), \
                patch.object(livewall, 'frame_path', return_value=Path('/cache/frame-x.png')), \
                patch.object(livewall, 'frame_failed', side_effect=lambda p: not done), \
                patch.object(livewall, 'overlay_capture', side_effect=lambda *a: done.append(1) or 'saved') as capture, \
                patch.object(livewall.time, 'monotonic', side_effect=lambda: clock['now']):
            livewall.CAPTURE_TRIED.clear()
            self.drive(5, {n: [tick] for n in range(2, 6)})
        self.assertEqual(capture.call_count, 1)
        self.assertTrue(FakeRenderer.instances[0].stopped)
        self.assertNotEqual(self.statuses[-1]['state'], 'error')

    def test_display_off_pauses_at_once(self):
        self.reason, self.mapped = 'dpms', False
        self.drive(1)
        self.assertEqual(FakeRenderer.instances[0].pauses, [True])

    def test_covering_windows_pause_on_an_event(self):
        livewall.START_GRACE = 0
        self.addCleanup(setattr, livewall, 'START_GRACE', 1.0)
        self.drive(3, {2: [lambda: setattr(self, 'reason', 'covered'), self.event]})
        self.assertEqual(self.statuses[-1]['state'], 'paused')
        self.assertEqual(FakeRenderer.instances[0].pauses[-1], True)

    def test_pause_not_confirmed_is_retried(self):
        livewall.START_GRACE = 0
        self.addCleanup(setattr, livewall, 'START_GRACE', 1.0)
        self.reason = 'covered'
        FakeRenderer.pause_ok = False
        states = []
        self.drive(2, {2: [lambda: states.append(self.statuses[-1]['state']), lambda: setattr(FakeRenderer, 'pause_ok', True)]})
        self.assertEqual(states, ['starting'])
        self.assertEqual(self.statuses[-1]['state'], 'paused')
        self.assertEqual(FakeRenderer.instances[0].pauses[-1], True)

    def test_theme_replacing_the_underlay_is_noticed(self):
        self.drive(2, {2: [lambda: setattr(self, 'shown', '/theme-wallpaper.png'), self.event]})
        self.assertEqual(self.wallpapers, [str(self.still), str(self.still)])
        self.assertTrue(FakeRenderer.instances[0].stopped)
        self.assertTrue(FakeRenderer.instances[1].running)

    def test_hyprpaper_is_never_changed_under_a_running_renderer(self):
        scene = dict(ITEM, type='scene', file='')
        ready = {'now': False}
        with patch.object(livewall, 'find_item', side_effect=lambda i: dict(scene)), \
                patch.object(livewall, 'frame_path', return_value=Path('/cache/frame.png')), \
                patch.object(livewall, 'frame_ready', side_effect=lambda p: ready['now']):
            self.drive(5, {3: [lambda: ready.update(now=True), self.event], 4: [self.event]})
        self.assertEqual(self.wallpapers, ['/static.png'])
        self.assertEqual(len(FakeRenderer.instances), 1)

    def test_underlay_that_cannot_be_set_does_not_loop_restarts(self):
        with patch.object(livewall, 'set_hyprpaper', return_value=False):
            self.drive(5, {3: [self.event]})
        self.assertEqual(len(FakeRenderer.instances), 1)

    def test_switching_items_stops_the_old_renderer(self):
        other = dict(ITEM, id='8', file='/w/8/b.mp4')
        with patch.object(livewall, 'find_item', side_effect=lambda i: {'7': dict(ITEM), '8': other}.get(i)):
            self.drive(2, {2: [lambda: self.change(item='8')]})
        self.assertTrue(FakeRenderer.instances[0].stopped)
        self.assertEqual(FakeRenderer.instances[1].item['id'], '8')

    def test_new_static_choice_reaches_the_main_screen(self):
        self.config['mode'] = 'static'
        choice = {'path': '/static.png'}
        clock = iter(range(0, 1000, 40))
        with patch.object(livewall, 'static_wallpaper', side_effect=lambda: choice['path']), \
                patch.object(livewall.time, 'monotonic', side_effect=lambda: next(clock)):
            self.drive(3, {2: [lambda: choice.update(path='/new.png')]})
        self.assertEqual(self.wallpapers, ['/static.png', '/new.png'])

    def test_switching_to_static_reads_the_new_choice_at_once(self):
        scene = dict(ITEM, type='scene', file='')
        choice = {'path': '/static.png'}
        with patch.object(livewall, 'find_item', side_effect=lambda i: dict(scene)), \
                patch.object(livewall, 'frame_path', return_value=Path('/cache/frame.png')), \
                patch.object(livewall, 'frame_ready', return_value=False), \
                patch.object(livewall, 'static_wallpaper', side_effect=lambda: choice['path']):
            self.drive(2, {2: [lambda: choice.update(path='/new.png'), lambda: self.change(mode='static')]})
        self.assertEqual(self.wallpapers, ['/static.png', '/new.png'])

    def test_unloaded_web_item_gets_its_frame_underneath(self):
        web = dict(ITEM, type='web', file='')
        ready = {'now': False}

        def unload():
            renderer = FakeRenderer.instances[-1]
            renderer.unloaded = True
            ready['now'] = True
        with patch.object(livewall, 'find_item', side_effect=lambda i: dict(web)), \
                patch.object(livewall, 'frame_path', return_value=Path('/cache/frame.png')), \
                patch.object(livewall, 'frame_ready', side_effect=lambda p: ready['now']):
            self.drive(3, {2: [unload]})
        self.assertEqual(self.wallpapers, ['/static.png', '/cache/frame.png'])

    def test_missing_item_reports_error_on_static(self):
        self.change(item='99')
        self.drive(1)
        self.assertEqual(self.statuses[-1]['state'], 'error')
        self.assertEqual(self.wallpapers[-1], '/static.png')

if __name__ == '__main__':
    unittest.main()
