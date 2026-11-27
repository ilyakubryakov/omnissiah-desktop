from pathlib import Path
import sys
import tempfile
import threading
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'lib'))
import oninix_dictation as d

@unittest.skipUnless(hasattr(d, 'paste_shortcut'), 'requires the clipboard dictation backend')
class DictationTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        for name in ('STATE', 'RUNTIME'):
            path = root / name.lower()
            path.mkdir()
            patcher = patch.object(d, name, path)
            patcher.start()
            self.addCleanup(patcher.stop)

    def test_legacy_draft_moves_to_runtime_on_upgrade(self):
        legacy = d.STATE / 'draft.txt'
        legacy.write_text('Русский and English', encoding='utf-8')
        with patch.object(threading.Thread, 'start'):
            recovered = d.Dictation()
        self.assertEqual((recovered.phase, recovered.text), ('review', 'Русский and English'))
        self.assertEqual((d.RUNTIME / 'draft.txt').read_text(encoding='utf-8'), recovered.text)
        self.assertFalse(legacy.exists())

    def test_paste_shortcut_per_window_kind(self):
        self.assertEqual(d.paste_shortcut({'class':'kitty'}),('CTRL SHIFT','code:55'))
        self.assertEqual(d.paste_shortcut({'class':'Emacs'}),('SHIFT','code:118'))
        self.assertEqual(d.paste_shortcut({'class':'google-chrome'}),('CTRL','code:55'))
        self.assertEqual(d.paste_shortcut({'class':'editor','xwayland':True}),('CTRL','code:55'))

    def test_wayland_window_also_pastes_without_wtype(self):
        target=dict(address='0x7b',pid=10,**{'class':'kitty'},xwayland=False)
        owner=unittest.mock.MagicMock();owner.poll.return_value=None
        keys=[]
        def run(command,**kwargs):
            out=b'text/plain;charset=utf-8\n' if '--list-types' in command else b'old clip'
            return unittest.mock.Mock(returncode=0,stdout=out)
        with patch.object(d,'executable',side_effect=lambda x:x),patch.object(d.subprocess,'run',side_effect=run),\
             patch.object(d.subprocess,'Popen',return_value=owner),patch.object(d,'focus',return_value=target),\
             patch.object(d.speech,'run',side_effect=lambda c,*a,**k:keys.append(c)),patch.object(d.time,'sleep'):
            d.insert_text('Привет мир',target,threading.Event())
        self.assertEqual(keys,[['hyprctl','dispatch',"hl.dsp.send_shortcut({mods='CTRL SHIFT', key='code:55', window='address:0x7b'})"]])
        self.assertFalse(any('wtype' in str(c) for c in keys))

    def test_xwayland_pastes_with_layout_independent_shortcut_and_restores_clipboard(self):
        target=dict(address='0x5a',pid=10,**{'class':'Chatgpt'},xwayland=True)
        owner=unittest.mock.MagicMock();owner.poll.return_value=None
        runs=[];keys=[]
        def run(command,**kwargs):
            runs.append((command,kwargs))
            out=b'text/plain;charset=utf-8\n' if '--list-types' in command else b'old clip'
            return unittest.mock.Mock(returncode=0,stdout=out)
        cancelled=threading.Event()
        with patch.object(d,'executable',side_effect=lambda x:x),patch.object(d.subprocess,'run',side_effect=run),\
             patch.object(d.subprocess,'Popen',return_value=owner),patch.object(d,'focus',return_value=target),\
             patch.object(d.speech,'run',side_effect=lambda c,*a,**k:keys.append(c)),patch.object(d.time,'sleep'):
            d.insert_text('Привет',target,cancelled)
        owner.stdin.write.assert_called_once_with('Привет'.encode())
        self.assertEqual(keys,[['hyprctl','dispatch',"hl.dsp.send_shortcut({mods='CTRL', key='code:55', window='address:0x5a'})"]])
        restore=runs[-1]
        self.assertEqual(restore[0],['wl-copy','--type','text/plain;charset=utf-8'])
        self.assertEqual(restore[1]['input'],b'old clip')
