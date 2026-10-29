#!/usr/bin/python3
"""Exercise native mail preferences in a bubblewrap-isolated home; no real accounts."""
from pathlib import Path
import shutil
import subprocess
import tempfile

RUNNER = r"""
import json,os,subprocess,time,sys
from pathlib import Path
root=Path(sys.argv[1]);config=str(root/'source/mail-settings-test.qml')
env=os.environ.copy();env['XDG_RUNTIME_DIR']=str(root/'runtime');Path(env['XDG_RUNTIME_DIR']).mkdir(mode=0o700,exist_ok=True)
wayland=env.get('WAYLAND_DISPLAY','wayland-1');env['WAYLAND_DISPLAY']=wayland if wayland.startswith('/') else os.environ.get('XDG_RUNTIME_DIR','/run/user/'+str(os.getuid()))+'/'+wayland
env.pop('DBUS_SESSION_BUS_ADDRESS',None);env.pop('OMAMAIL_BIN',None)
base=['quickshell','ipc','-p',config,'call','mailsettings']
def call(method):return subprocess.check_output(base+[method],env=env,text=True,stderr=subprocess.DEVNULL).strip()
def wait(predicate):
 deadline=time.monotonic()+15
 while time.monotonic()<deadline:
  try:
   value=json.loads(call('status'))
   if predicate(value):return value
  except (subprocess.CalledProcessError,ValueError):pass
  time.sleep(.1)
 raise AssertionError('Settings condition timed out')
def launch():
 result=subprocess.run(['quickshell','-n','-d','-p',config],env=env,capture_output=True,text=True,check=True)
 with (root/'launch.log').open('a') as log:log.write(result.stdout+result.stderr)
 return wait(lambda s:s['ready'])
def quit_app():
 try:call('quit')
 except subprocess.CalledProcessError:pass
 deadline=time.monotonic()+10
 while time.monotonic()<deadline:
  if config not in subprocess.run(['quickshell','list','-a','-j'],env=env,capture_output=True,text=True).stdout:return
  time.sleep(.1)
 raise AssertionError('Fixture did not quit')
try:
 initial=launch();assert initial['interval']==120 and not initial['notifications'] and not initial['images'],initial
 call('save');wait(lambda s:s['interval']==300 and s['notifications'] and s['images'])
 dashboard=Path.home()/'.config/starlink-dashboard/mail/omamail/dashboard.json'
 window=dashboard.with_name('window.json')
 deadline=time.monotonic()+5
 while time.monotonic()<deadline:
  if dashboard.exists() and window.exists() and json.loads(window.read_text()).get('alwaysShowImages'):break
  time.sleep(.1)
 assert json.loads(dashboard.read_text())['refreshIntervalSec']==300
 assert json.loads(dashboard.read_text())['notifyNewMail']=='On'
 assert json.loads(window.read_text())['alwaysShowImages']
 assert dashboard.stat().st_mode&0o777==0o600 and window.stat().st_mode&0o777==0o600
 call('notify');state=wait(lambda s:len(s['activations'])==2)
 assert {(v['accountId'],v['messageId']) for v in state['activations']}=={('first-account','message-one'),('second-account','message-two')}
 call('fail');state=wait(lambda s:bool(s['bridgeError']));assert len(state['activations'])==2
 quit_app();restored=launch();assert restored['interval']==300 and restored['notifications'] and restored['images'],restored
 assert not restored['error'],restored
 quit_app()
 print('PASS: real preference files, private permissions, restart persistence, independent notification targets, failure reporting and no click on failure; isolated profile only')
finally:
 quit_app()

"""


def main():
    repo=Path(__file__).resolve().parents[1]
    home=Path.home()
    backend=home/'.local/share/starlink-dashboard/mail/runtime-data/omamail/bin/omamail'
    if not backend.is_file():raise SystemExit('Install the pinned mail backend before running this test; see README.md')
    if not shutil.which('bwrap'):raise SystemExit('This isolated native test requires bubblewrap (bwrap)')
    with tempfile.TemporaryDirectory(prefix='stardock-mail-settings-',dir='/tmp') as temporary:
        root=Path(temporary);source=root/'source';source.mkdir()
        paths=subprocess.check_output(['git','ls-files','--cached','--others','--exclude-standard','-z'],cwd=repo).split(b'\0')
        for raw in paths:
            if not raw:continue
            relative=Path(raw.decode());original=repo/relative;target=source/relative
            target.parent.mkdir(parents=True,exist_ok=True)
            if original.is_symlink():target.symlink_to(original.readlink())
            else:shutil.copy2(original,target)
        isolated_backend=root/'profile/.local/share/starlink-dashboard/mail/runtime-data/omamail/bin/omamail'
        isolated_backend.parent.mkdir(parents=True)
        shutil.copy2(backend,isolated_backend)
        (root/'runner.py').write_text(RUNNER)
        subprocess.run(['bwrap','--ro-bind','/','/','--bind',str(root/'profile'),str(home),
            '--bind',str(root),str(root),'--dev-bind','/dev','/dev','--proc','/proc',
            '--chdir',str(source),'/usr/bin/python3',str(root/'runner.py'),str(root)],check=True)


if __name__=='__main__':main()
