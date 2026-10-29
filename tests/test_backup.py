import importlib.util
import json
from pathlib import Path
import stat
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('backup', Path(__file__).parents[1] / 'scripts/dashboard_backup.py')
b = importlib.util.module_from_spec(spec)
spec.loader.exec_module(b)


class BackupTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.manager = b.Backups(self.tmp.name)

    def put(self, key, value):
        b.private_write(self.manager.target(key), b.encode(value))

    def backup(self):
        return Path(self.manager.create())

    def test_excludes_credentials_and_unknown_fields(self):
        self.put('accounts', {'accounts': [{'id': 'a', 'label': 'Mail', 'clientSecret': 'SECRET', 'password': 'SECRET', 'server': 'private'}]})
        self.put('preferences', {'bodyZoom': 3, 'oauthPort': 1234, 'apiKey': 'SECRET'})
        self.put('dashboard', {'rss': {'feeds': [{'url': 'https://example.com/rss', 'count': 5}, {'url': 'https://example.com/rss?token=SECRET'}]}, 'secret': 'SECRET'})
        path = self.backup()
        self.assertNotIn('SECRET', path.read_text())
        self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
        files = json.loads(path.read_text())['files']
        self.assertEqual(files['accounts']['accounts'], [{'id': 'a', 'label': 'Mail'}])
        self.assertEqual(len(files['dashboard']['rss']['feeds']), 1)

    def test_popup_appearance_is_included_in_backup(self):
        self.put('dashboard',{'popupAppearance':{'shadowSize':30,'shadowColor':'#123456','overlayOpacity':45,'unknown':'SECRET'}})
        path=self.backup()
        self.assertEqual(self.manager.preview(path)['files']['dashboard']['popupAppearance'],{'shadowSize':30,'shadowColor':'#123456','overlayOpacity':45})
        self.assertNotIn('SECRET',path.read_text())

    def test_font_overrides_are_backed_up_without_unknown_fields(self):
        self.put('dashboard', {'fontSizes':{'emailBody':18,'notesBody':20,'summaries':14,'rssBody':16,'rssHeadline':20,'unknownSecret':'SECRET'}})
        path=self.backup()
        saved=self.manager.preview(path)['files']['dashboard']['fontSizes']
        self.assertEqual(saved,{'emailBody':18,'notesBody':20,'summaries':14,'rssBody':16,'rssHeadline':20})
        self.assertNotIn('SECRET',path.read_text())

    def test_sidebar_width_and_rss_visibility_survive_backup(self):
        self.put('dashboard', {'sidebarWidthPercent':25, 'rss':{'enabled':False,'feeds':[]}})
        path=self.backup()
        saved=self.manager.preview(path)['files']['dashboard']
        self.assertEqual(saved['sidebarWidthPercent'],25)
        self.assertFalse(saved['rss']['enabled'])

    def test_live_notes_and_preview_are_separate(self):
        self.put('notes', [{'title': 'Old', 'body': 'old'}])
        result = self.manager.run({'op': 'backup', 'live': {'notes': [{'title': 'Live', 'body': 'private body'}]}})
        preview = self.manager.run({'op': 'preview', 'path': result['created']})['preview']
        self.assertEqual(preview['notes'], 1)
        self.assertNotIn('private body', json.dumps(preview))
        self.assertEqual(json.loads(Path(result['created']).read_text())['files']['notes'][0]['title'], 'Live')

    def test_retention_keeps_unrelated_files(self):
        self.manager.run({'op': 'configure', 'settings': {'directory': str(Path(self.tmp.name)/'backups'), 'keep': 2}})
        self.put('notes', [])
        self.backup(); self.backup(); self.backup()
        folder = Path(self.manager.settings()['directory'])
        unrelated = folder/'starlink-backup-unrelated.json'
        unrelated.write_text('[]')
        self.backup()
        self.assertTrue(unrelated.exists())
        self.assertEqual(len(self.manager.list()), 2)

    def test_schedule_catches_up_and_defaults_off(self):
        self.assertFalse(self.manager.due())
        self.manager.run({'op': 'configure', 'settings': {'directory': str(Path(self.tmp.name)/'backups'), 'schedule': 'daily'}})
        self.assertTrue(self.manager.due())
        self.put('notes', [])
        self.backup()
        self.assertFalse(self.manager.due())
        self.manager.record(lastBackup='2000-01-01T00:00:00+00:00')
        self.assertTrue(self.manager.due())

    def test_changed_backup_refused(self):
        self.put('notes', [{'title': 'Saved', 'body': 'a'}])
        path = self.backup(); digest = self.manager.preview(path)['digest']
        path.write_text(path.read_text()+' ')
        for operation in (self.manager.stage, self.manager.restore):
            with self.assertRaisesRegex(ValueError, 'changed'):
                operation(path, digest)
        self.assertEqual(b.read_json(self.manager.target('notes'))[0]['title'], 'Saved')

    def test_restore_merges_matching_accounts_and_blocks_remote_images(self):
        self.put('accounts', {'accounts': [{'id': 'a', 'label': 'Saved', 'clientSecret': 'original'}]})
        self.put('reading', {'alwaysShowImages': True, 'bodyZoom': 1.2})
        path = self.backup(); digest = self.manager.preview(path)['digest']
        self.put('accounts', {'accounts': [{'id': 'a', 'label': 'New', 'clientSecret': 'CURRENT'}, {'id': 'b', 'label': 'Other'}]})
        result = self.manager.restore(path, digest)
        accounts = b.read_json(self.manager.target('accounts'))['accounts']
        self.assertEqual(accounts[0], {'id': 'a', 'label': 'Saved', 'clientSecret': 'CURRENT'})
        self.assertEqual(accounts[1]['label'], 'Other')
        self.assertFalse(b.read_json(self.manager.target('reading'))['alwaysShowImages'])
        self.assertTrue(Path(result['safetyBackup']).exists())
        self.assertNotIn('CURRENT', Path(result['safetyBackup']).read_text())

    def test_restore_does_not_create_accounts(self):
        self.put('accounts', {'accounts': [{'id': 'a', 'label': 'Saved'}]})
        path = self.backup(); digest = self.manager.preview(path)['digest']
        self.manager.target('accounts').unlink()
        self.manager.restore(path, digest)
        self.assertFalse(self.manager.target('accounts').exists())

    def test_restore_rolls_back_on_write_failure(self):
        self.put('notes', [{'title': 'Saved', 'body': 'saved'}]); self.put('dashboard', {'textScale': 1})
        path = self.backup(); digest = self.manager.preview(path)['digest']
        self.put('notes', [{'title': 'Current', 'body': 'current'}]); self.put('dashboard', {'textScale': 2})
        original = {k: self.manager.target(k).read_bytes() for k in ('notes', 'dashboard')}
        real = b.private_write
        def fail(target, data):
            if target == self.manager.target('notes'):
                raise OSError('test write failure')
            real(target, data)
        with patch.object(b, 'private_write', side_effect=fail):
            with self.assertRaisesRegex(OSError, 'test write failure'):
                self.manager.restore(path, digest)
        for key, data in original.items():
            self.assertEqual(self.manager.target(key).read_bytes(), data)

    def test_unknown_sections_and_symlinks_refused(self):
        path = Path(self.tmp.name)/'bad.json'
        path.write_bytes(b.encode({'format': b.FORMAT, 'version': 1, 'files': {'../../escape': {}}}))
        with self.assertRaises(ValueError): self.manager.preview(path)
        self.put('notes', [])
        path = self.backup(); digest = self.manager.preview(path)['digest']
        target = self.manager.target('notes'); target.unlink(); target.symlink_to(path)
        with self.assertRaises(ValueError): self.manager.restore(path, digest)

    def test_oversized_registry_refused_before_writes(self):
        self.put('accounts', {'accounts': [{'id': 'a', 'signature': 'x'*(1024*1024)}]})
        path = self.backup(); digest = self.manager.preview(path)['digest']
        self.put('accounts', {'accounts': [{'id': 'a', 'label': 'Current'}]})
        with self.assertRaisesRegex(ValueError, 'registry limit'): self.manager.restore(path, digest)
        self.assertEqual(b.read_json(self.manager.target('accounts'))['accounts'][0]['label'], 'Current')
