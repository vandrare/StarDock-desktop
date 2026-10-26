#!/usr/bin/python3
"""Write the small host preference files used by embedded Omamail."""
import json
import os
from pathlib import Path
import sys
import tempfile

ALLOWED = {'credentials.json', 'window.json', 'calendars.json', 'dashboard.json'}

def write(name, text):
    if name not in ALLOWED:
        raise ValueError('Invalid mail preference file')
    json.loads(text)
    directory = Path.home()/'.config/starlink-dashboard/mail/omamail'
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    handle, temporary = tempfile.mkstemp(dir=directory, prefix='.prefs-')
    try:
        with os.fdopen(handle, 'w') as stream:
            stream.write(text)
        os.replace(temporary, directory/name)
    finally:
        if os.path.exists(temporary): os.unlink(temporary)

if __name__ == '__main__':
    try:
        request = json.load(sys.stdin)
        write(request['name'], request['text'])
        print(json.dumps({'ok': True}))
    except Exception:
        print(json.dumps({'ok': False, 'error': 'Could not save mail preferences'}))
