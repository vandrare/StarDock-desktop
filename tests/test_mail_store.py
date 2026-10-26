import importlib.util
import json
from pathlib import Path
import stat
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('mail_store', Path(__file__).parents[1]/'scripts/mail_store.py')
store = importlib.util.module_from_spec(spec)
spec.loader.exec_module(store)

class MailStoreTests(unittest.TestCase):
    def test_preferences_replace_atomically_with_private_permissions(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(store.Path, 'home', return_value=Path(directory)):
            store.write('window.json', '{"mailbox":"inbox"}')
            store.write('window.json', '{"mailbox":"sent"}')
            path = Path(directory)/'.config/starlink-dashboard/mail/omamail/window.json'
            self.assertEqual(json.loads(path.read_text()), {'mailbox':'sent'})
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
            self.assertEqual(list(path.parent.glob('.prefs-*')), [])

    def test_calendar_preferences_roundtrip_privately(self):
        value={'calendarDefaultView':'week','calendarWeekStart':0,'calendarRemindersEnabled':True,'calendarSnoozeMinutes':15,'calendarDuration':30,'calendarTimeZone':'America/Phoenix'}
        with tempfile.TemporaryDirectory() as directory, patch.object(store.Path,'home',return_value=Path(directory)):
            store.write('dashboard.json',json.dumps(value))
            path=Path(directory)/'.config/starlink-dashboard/mail/omamail/dashboard.json'
            self.assertEqual(json.loads(path.read_text()),value)
            self.assertEqual(stat.S_IMODE(path.stat().st_mode),0o600)

    def test_rejects_paths_and_unrecognized_files(self):
        for name in ['../accounts.json', '/tmp/mail.json', 'accounts.json', 'other.json']:
            with self.assertRaises(ValueError): store.write(name, '{}')

    def test_invalid_json_does_not_replace_existing_preferences(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(store.Path, 'home', return_value=Path(directory)):
            store.write('window.json', '{}')
            with self.assertRaises(ValueError):store.write('window.json', 'broken')
            path=Path(directory)/'.config/starlink-dashboard/mail/omamail/window.json'
            self.assertEqual(path.read_text(), '{}')
