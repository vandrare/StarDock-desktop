#!/usr/bin/python3
"""Clone GitHub and test installation/backend/launchers in a private home."""
from pathlib import Path
import shutil
import subprocess
import tempfile

RUNNER = r'''
import json,os,subprocess,sys,time
from pathlib import Path
root=Path(sys.argv[1]);source=root/'checkout';home=Path.home();config=str(source/'shell.qml')
env=os.environ.copy();env['XDG_RUNTIME_DIR']=str(root/'runtime');Path(env['XDG_RUNTIME_DIR']).mkdir(mode=0o700)
wayland=env.get('WAYLAND_DISPLAY','wayland-1');env['WAYLAND_DISPLAY']=wayland if wayland.startswith('/') else os.environ.get('XDG_RUNTIME_DIR','/run/user/'+str(os.getuid()))+'/'+wayland
for key in ('DBUS_SESSION_BUS_ADDRESS','OMAMAIL_BIN','XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_STATE_HOME','XDG_CACHE_HOME'):env.pop(key,None)
base=['quickshell','ipc','-p',config,'call','dashboard']
def call(method):return subprocess.check_output(base+[method],env=env,text=True,stderr=subprocess.DEVNULL).strip()
def wait(predicate,timeout=120):
 deadline=time.monotonic()+timeout;last=None
 while time.monotonic()<deadline:
  try:
   last=json.loads(call('status'))
   if predicate(last):return last
  except (subprocess.CalledProcessError,ValueError):pass
  time.sleep(.25)
 raise AssertionError('Installation condition timed out: '+repr(last))
def instances():
 return subprocess.check_output(['quickshell','list','-a','-j'],env=env,text=True).count(config)
try:
 subprocess.run(['sh',str(source/'install.sh')],env=env,check=True,capture_output=True)
 backend_env=dict(env,XDG_DATA_HOME=str(home/'.local/share/starlink-dashboard/mail/runtime-data'))
 subprocess.run(['/usr/bin/python3',str(source/'vendor/omamail/scripts/backend-runtime.py'),'install'],env=backend_env,check=True,capture_output=True,text=True,timeout=180)
 launcher=home/'.local/bin/stardock';desktop=home/'.local/share/applications/stardock.desktop'
 assert launcher.stat().st_mode&0o111 and desktop.exists()
 subprocess.run([str(launcher)],env=env,check=True,capture_output=True)
 state=wait(lambda s:s['mailReady']);assert state['mailVersion']=='0.11.0' and state['mailAccounts']==0,state
 assert instances()==1,instances()
 subprocess.run([str(launcher)],env=env,check=True,capture_output=True);assert instances()==1
 subprocess.run(['gio','launch',str(desktop)],env=env,check=True,capture_output=True);time.sleep(1);assert instances()==1
 state=wait(lambda s:s['forecastDays']==7 and s['articles']>0 and s['radarFrames']>0)
 call('quit');deadline=time.monotonic()+15
 while instances() and time.monotonic()<deadline:time.sleep(.1)
 assert instances()==0
 subprocess.run([str(launcher)],env=env,check=True,capture_output=True)
 state=wait(lambda s:s['mailReady']);assert state['mailAccounts']==0
 revision=subprocess.check_output(['git','rev-parse','--short','HEAD'],cwd=source,text=True).strip()
 print('PASS: fresh GitHub '+revision+', installer, downloaded pinned backend 0.11.0, command/desktop launchers, single instance, relaunch, RSS, 7-day weather and animated radar; isolated profile, no accounts')
finally:
 try:call('quit')
 except subprocess.CalledProcessError:pass
 deadline=time.monotonic()+10
 while instances() and time.monotonic()<deadline:time.sleep(.1)
 if instances():subprocess.run(['quickshell','kill','-p',config],env=env,capture_output=True)
'''

def main():
    if not shutil.which('bwrap'):raise SystemExit('Requires bubblewrap (bwrap)')
    with tempfile.TemporaryDirectory(prefix='stardock-fresh-install-',dir='/tmp') as temporary:
        root=Path(temporary);(root/'profile').mkdir()
        subprocess.run(['git','clone','--depth','1','https://github.com/vandrare/StarDock-desktop.git',str(root/'checkout')],check=True,capture_output=True)
        (root/'runner.py').write_text(RUNNER)
        subprocess.run(['bwrap','--ro-bind','/','/','--bind',str(root/'profile'),str(Path.home()),'--bind',str(root),str(root),'--dev-bind','/dev','/dev','--proc','/proc','--chdir',str(root/'checkout'),'/usr/bin/python3',str(root/'runner.py'),str(root)],check=True)

if __name__=='__main__':main()
