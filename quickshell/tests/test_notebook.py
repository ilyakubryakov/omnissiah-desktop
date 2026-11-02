import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'dotfiles/.local/lib'))
import station_notebook as notebook

class NotebookTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        root = Path(self.temp.name)
        self.vault = root / 'vault'
        (self.vault / '.obsidian').mkdir(parents=True)
        self.state = root / 'state'
        self.patch = patch.multiple(notebook, STATE=self.state, DEFAULT_VAULT=self.vault)
        self.patch.start()

    def tearDown(self):
        self.patch.stop()
        self.temp.cleanup()

    def test_notes_save_markdown_and_preserve_external_frontmatter(self):
        note = notebook.handle(dict(op='new', title='A thought', body='- [ ] first\n- [x] second'))
        path = self.vault / 'Quick Notes' / note['id']
        self.assertTrue(path.name.startswith('Quick Note '))
        raw = path.read_text().replace('status: draft', 'status: active\ncustom: keep')
        path.write_text(raw)
        note = notebook.handle(dict(op='read', id=note['id']))
        notebook.handle(dict(op='save', id=note['id'], revision=note['revision'], title='Updated', body='text'))
        self.assertIn('custom: keep', path.read_text())
        self.assertIn('# Updated\ntext', path.read_text())

    def test_list_skips_a_note_that_is_not_utf8(self):
        notebook.handle(dict(op='new', title='Readable', body='text'))
        (notebook.notes_dir() / 'Broken.md').write_bytes(b'\xff\xfe broken')
        self.assertEqual([n['title'] for n in notebook.handle(dict(op='list'))], ['Readable'])

    def test_read_save_without_edits_preserves_exact_bytes_and_mtime(self):
        samples = [
            '', 'Сразу текст', '\n\nСразу текст\n', ' \n\t\nТекст\n\n',
            '---\nupdated: 2001-01-01\ncustom: keep\n---\nТекст',
            '---\n---\n\n\nТекст\n', '---\ncustom: keep\n---',
            '# Title', '# Title\nbody', '\n\n# Title  \n\n\nbody\n\n',
            '# \n\nbody', '\ufeff\n# Title\r\n\r\nbody\r\n',
            '---\r\nupdated: 2001-01-01\r\n---\r\n\r\ntext\r\n',
            '\r\n# Title\r\n\r\nbody\r\n', '# Title\r\n\nbody\r\nsecond\n',
        ]
        for raw in samples:
            with self.subTest(raw=repr(raw)):
                path = notebook.notes_dir() / 'Existing.md'
                original = raw.encode('utf-8')
                path.write_bytes(original)
                before = path.stat().st_mtime_ns
                note = notebook.handle(dict(op='read', id=path.name))
                saved = notebook.handle(dict(note, op='save'))
                self.assertEqual(path.read_bytes(), original)
                self.assertEqual(path.stat().st_mtime_ns, before)
                self.assertEqual(saved['revision'], note['revision'])

    def test_body_edit_preserves_missing_heading_and_original_spacing(self):
        for prefix in ('', '\n\n', ' \n\t\n', '---\ncustom: keep\n---\n\n', '\ufeff\r\n'):
            with self.subTest(prefix=repr(prefix)):
                raw = prefix + 'original text\n\n'
                path = notebook.notes_dir() / 'Existing.md'
                path.write_bytes(raw.encode())
                note = notebook.handle(dict(op='read', id=path.name))
                self.assertFalse(note['has_heading'])
                saved = notebook.handle(dict(note, op='save', body=note['body'].replace('original', 'edited')))
                self.assertFalse(saved['has_heading'])
                self.assertEqual(path.read_bytes(), raw.replace('original', 'edited').encode())

    def test_existing_heading_spacing_and_crlf_survive_editor_normalization(self):
        raw = '\ufeff---\r\ncustom: keep\r\n---\r\n \r\n# Title  \r\n\r\n\r\noriginal text\r\n'
        path = notebook.notes_dir() / 'Existing.md'
        path.write_bytes(raw.encode())
        note = notebook.handle(dict(op='read', id=path.name))
        self.assertTrue(note['has_heading'])
        normalized = note['body'].replace('\r\n', '\n')
        notebook.handle(dict(note, op='save', body=normalized))
        self.assertEqual(path.read_bytes(), raw.encode())
        notebook.handle(dict(note, op='save', body=normalized.replace('original', 'edited')))
        self.assertEqual(path.read_bytes(), raw.replace('original', 'edited').encode())

    def test_leading_body_newlines_do_not_grow_across_autosaves(self):
        for raw in ('body', '# Title\nbody', '# Title\n\nbody'):
            with self.subTest(raw=raw):
                path = notebook.notes_dir() / 'Existing.md'
                path.write_text(raw)
                note = notebook.handle(dict(op='read', id=path.name))
                body = '\n\n' + note['body']
                saved = notebook.handle(dict(note, op='save', body=body))
                self.assertEqual(saved['body'], body)
                expected = path.read_bytes()
                notebook.handle(dict(saved, op='save', body=body))
                self.assertEqual(path.read_bytes(), expected)
                notebook.handle(dict(saved, op='save', body=body + '!'))
                self.assertEqual(path.read_bytes(), expected + b'!')

    def test_explicit_rename_adds_heading_without_removing_leading_blank_lines(self):
        path = notebook.notes_dir() / 'Existing.md'
        raw = '---\ncustom: keep\n---\n\n\nbody\n'
        path.write_text(raw)
        note = notebook.handle(dict(op='read', id=path.name))
        saved = notebook.handle(dict(note, op='save', title='Chosen title'))
        self.assertTrue(saved['has_heading'])
        self.assertEqual(saved['body'], note['body'])
        self.assertEqual(path.read_text(), raw.replace('body', '# Chosen title\nbody'))
        notebook.handle(dict(saved, op='save', title='Renamed again'))
        self.assertEqual(path.read_text(), raw.replace('body', '# Renamed again\nbody'))

    def test_body_can_be_added_to_a_heading_or_frontmatter_at_eof(self):
        for raw, expected in [('# Title', '# Title\nbody'),
                              ('---\ncustom: keep\n---', '---\ncustom: keep\n---\nbody')]:
            with self.subTest(raw=raw):
                path = notebook.notes_dir() / 'Existing.md'
                path.write_text(raw)
                note = notebook.handle(dict(op='read', id=path.name))
                notebook.handle(dict(note, op='save', body='body'))
                self.assertEqual(path.read_text(), expected)

    def test_line_ending_only_external_edit_is_still_a_conflict(self):
        path = notebook.notes_dir() / 'Existing.md'
        path.write_bytes(b'# Title\r\n\r\nbody\r\n')
        note = notebook.handle(dict(op='read', id=path.name))
        external = path.read_bytes().replace(b'\r\n', b'\n')
        path.write_bytes(external)
        with self.assertRaisesRegex(notebook.NotebookError, 'changed'):
            notebook.handle(dict(note, op='save', body='edited'))
        self.assertEqual(path.read_bytes(), external)
        self.assertEqual(json.loads((self.state / 'draft.json').read_text())['body'], 'edited')

    def test_draft_loaded_by_the_old_lossy_parser_requires_a_fresh_read(self):
        path = notebook.notes_dir() / 'Existing.md'
        original = b'\n\noriginal text\n'
        path.write_bytes(original)
        old_revision = hashlib.sha256(original).hexdigest()
        with self.assertRaises(notebook.NotebookError):
            notebook.handle(dict(op='save', id=path.name, title='Existing', body='edited text\n', revision=old_revision))
        self.assertEqual(path.read_bytes(), original)
        self.assertEqual(json.loads((self.state / 'draft.json').read_text())['body'], 'edited text\n')

    def test_sync_conflict_keeps_both_original_and_draft(self):
        note = notebook.handle(dict(op='new', title='A', body='old'))
        path = self.vault / 'Quick Notes' / note['id']
        path.write_text('from another device')
        request = dict(op='save', id=note['id'], revision=note['revision'], title='A', body='my edit')
        with self.assertRaisesRegex(notebook.NotebookError, 'changed'):
            notebook.handle(request)
        self.assertEqual(path.read_text(), 'from another device')
        self.assertEqual(json.loads((self.state / 'draft.json').read_text())['body'], 'my edit')
        copy = notebook.handle(dict(request, op='new'))
        self.assertNotEqual(note['id'], copy['id'])
        self.assertEqual(copy['body'], 'my edit')

    def test_explicit_reload_discards_recovered_draft_and_hidden_notes_are_skipped(self):
        note = notebook.handle(dict(op='new', title='Original', body='saved'))
        notebook.write_json('draft.json', dict(id=note['id'], title='Unfinished', body='draft'))
        (self.vault / 'Quick Notes' / '.hidden.md').write_text('hidden')
        self.assertEqual(len(notebook.handle(dict(op='list'))), 1)
        self.assertEqual(notebook.handle(dict(op='reload', id=note['id']))['title'], 'Original')
        self.assertEqual(notebook.handle(dict(op='status'))['draft'], {})

    def test_traversal_and_symlink_refused(self):
        with self.assertRaises(notebook.NotebookError):
            notebook.handle(dict(op='read', id='../outside.md'))
        folder = notebook.notes_dir()
        target = self.vault / 'outside.md'
        target.write_text('untouched')
        (folder / 'link.md').symlink_to(target)
        with self.assertRaises(notebook.NotebookError):
            notebook.handle(dict(op='save', id='link.md', body='bad', revision=''))
        self.assertEqual(target.read_text(), 'untouched')

    def test_missing_vault_does_not_create_fake_vault_and_keeps_draft(self):
        (self.vault / '.obsidian').rmdir()
        with self.assertRaises(notebook.NotebookError):
            notebook.handle(dict(op='new', title='A', body='safe'))
        self.assertFalse((self.vault / 'Quick Notes').exists())
        self.assertEqual(notebook.handle(dict(op='status'))['draft']['body'], 'safe')

    def test_calculator_is_decimal_and_never_executes_code(self):
        self.assertEqual(notebook.calculate('0.1 + 0.2'), '0.3')
        self.assertEqual(notebook.calculate('(125 + 75) * 1.21'), '242')
        self.assertEqual(notebook.calculate('sqrt(144) + 2^3'), '20')
        for value in ('__import__("os").system("true")', '[1][0]', '10 ** 10000000', '1/0', 'True', '1e999'):
            with self.assertRaises(notebook.NotebookError, msg=value):
                notebook.calculate(value)

    def test_timer_restart_pause_snooze_and_exactly_once_delivery(self):
        with patch.object(notebook.time, 'time', return_value=1000):
            job = notebook.handle(dict(op='add', kind='timer', seconds=60, label='Tea'))[0]
        with patch.object(notebook.time, 'time', return_value=1020):
            paused = notebook.handle(dict(op='pause', id=job['id']))[0]
        self.assertEqual(paused['remaining'], 40)
        delivered = []
        notebook.tick(delivered.append, now=2000)
        self.assertEqual(delivered, [])
        with patch.object(notebook.time, 'time', return_value=2000):
            notebook.handle(dict(op='resume', id=job['id']))
        notebook.tick(delivered.append, now=2041)
        notebook.tick(delivered.append, now=2042)
        self.assertEqual(len(delivered), 1)
        with patch.object(notebook.time, 'time', return_value=2050):
            notebook.handle(dict(op='snooze', id=job['id']))
        notebook.tick(delivered.append, now=2651)
        self.assertEqual(len(delivered), 2)
        self.assertEqual(notebook.handle(dict(op='status'))['jobs'][0]['state'], 'fired')
        notebook.handle(dict(op='done', id=job['id']))
        self.assertEqual(notebook.jobs()[0]['state'], 'done')

    def test_notification_failure_retains_due_reminder(self):
        notebook.handle(dict(op='add', kind='timer', seconds=1))
        def fail(_): raise OSError('notification bus down')
        with self.assertRaises(OSError):
            notebook.tick(fail, now=10**12)
        self.assertEqual(notebook.jobs()[0]['state'], 'running')

if __name__ == '__main__':
    unittest.main()
