import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT=Path(__file__).parents[1]/'scripts/notify_mail.py'
spec=importlib.util.spec_from_file_location('notify_mail',SCRIPT)
notify=importlib.util.module_from_spec(spec)
spec.loader.exec_module(notify)


class NotificationTests(unittest.TestCase):
    def test_sender_text_is_literal_not_options_or_markup(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            stub=root/'notify-send'
            stub.write_text('#!/usr/bin/python3\nimport json,os,sys\nopen(os.environ["STARDOCK_TEST_ARGS"],"w").write(json.dumps(sys.argv[1:]))\nprint("default")\n')
            stub.chmod(0o755)
            captured=root/'args.json'
            env=dict(os.environ,PATH=directory,STARDOCK_TEST_ARGS=str(captured))
            marker=root/'must-not-exist'
            title='--action=evil <img src="https://example.test/tracker">'
            body='$(touch '+str(marker)+') `touch '+str(marker)+'`\n& <b>text</b>'
            result=subprocess.run(['/usr/bin/python3',str(SCRIPT)],input=json.dumps({'title':title,'body':body}),text=True,capture_output=True,env=env,check=True)
            args=json.loads(captured.read_text())
            boundary=args.index('--')
            self.assertEqual(args[boundary+1:], [notify.escape(title,quote=False),notify.escape(body,quote=False)])
            self.assertFalse(marker.exists())
            self.assertNotIn('--action=evil',args[:boundary])
            self.assertEqual(result.stdout.strip(),'default')

    def test_invalid_input_never_starts_notify_send(self):
        with tempfile.TemporaryDirectory() as directory:
            marker=Path(directory)/'started'
            stub=Path(directory)/'notify-send'
            stub.write_text('#!/usr/bin/python3\nfrom pathlib import Path\nPath('+repr(str(marker))+').touch()\n')
            stub.chmod(0o755)
            for payload in ('[]',json.dumps({'title':'bad\0title','body':'x'}),json.dumps({'title':{},'body':'x'}),'x'*65537):
                result=subprocess.run(['/usr/bin/python3',str(SCRIPT)],input=payload,text=True,capture_output=True,env=dict(os.environ,PATH=directory))
                self.assertNotEqual(result.returncode,0)
                self.assertFalse(marker.exists())
