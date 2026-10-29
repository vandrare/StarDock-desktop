#!/usr/bin/python3
"""Exercise the real restore/quit/relaunch path in a private filesystem profile."""
from pathlib import Path
import shutil
import subprocess
import tempfile

IPC = '''
    function restoreTestState(): string {return JSON.stringify({pid:Quickshell.processId,loaded:root.configLoaded && root.notesLoaded,ready:backupService.ready,busy:backupService.busy,error:backupService.error,notes:root.savedNotes,config:root.config,state:backupService.state,preview:backupService.preview})}
    function restoreTestBackup(): void {backupService.run({op:"backup"})}
    function restoreTestChange(): void {dashboard.notesEdited([{title:"Current synthetic note",body:"Current\\ncontent",updated:2}]);dashboard.configurationEdited(Object.assign({},root.config,{textScale:1.25,sidebarWidthPercent:25}));root.flushDashboardFiles(function(ok){if(!ok)throw new Error("Test flush failed")})}
    function restoreTestPreview(path:string): void {backupService.run({op:"preview",path:path})}
    function restoreTestApply(): void {backupService.restore()}
    function restoreTestVisual(light:bool,narrow:bool,settings:bool): void {window.visible=true;dashboard.themeBackground=light?"#f5f5f5":"#1a1b26";dashboard.themeForeground=light?"#202020":"#c0caf5";dashboard.themeAccent=light?"#0055aa":"#7aa2f7";dashboard.anchors.fill=null;dashboard.width=narrow?760:window.width;dashboard.height=window.height;if(settings)dashboard.openSettings()}
    function restoreTestCapture(path:string,settings:bool): void {var item=settings?dashboard.Overlay.overlay:dashboard;item.grabToImage(function(result){result.saveToFile(path)})}

'''
RUNNER = r'''
import json,os,subprocess,sys,time
from pathlib import Path
root=Path(sys.argv[1]);source=root/'source';home=Path.home();config=str(source/'shell.qml')
env=os.environ.copy();env['XDG_RUNTIME_DIR']=str(root/'runtime');Path(env['XDG_RUNTIME_DIR']).mkdir(mode=0o700)
wayland=env.get('WAYLAND_DISPLAY','wayland-1');env['WAYLAND_DISPLAY']=wayland if wayland.startswith('/') else os.environ.get('XDG_RUNTIME_DIR','/run/user/'+str(os.getuid()))+'/'+wayland
for key in ('DBUS_SESSION_BUS_ADDRESS','OMAMAIL_BIN','XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_STATE_HOME','XDG_CACHE_HOME'):env.pop(key,None)
base=['quickshell','ipc','-p',config,'call','dashboard']
def call(method,*args):return subprocess.check_output(base+[method,*args],env=env,text=True,stderr=subprocess.DEVNULL).strip()
def wait(predicate):
 deadline=time.monotonic()+35
 while time.monotonic()<deadline:
  try:
   state=json.loads(call('restoreTestState'))
   if predicate(state):return state
  except (subprocess.CalledProcessError,ValueError):pass
  time.sleep(.15)
 raise AssertionError('Restore condition timed out')
def ready(s):return s['loaded'] and s['ready'] and not s['busy']
def read(path):return json.loads(path.read_text())
try:
 subprocess.run(['sh',str(source/'install.sh')],env=env,check=True,capture_output=True)
 subprocess.run([str(home/'.local/bin/stardock')],env=env,check=True,capture_output=True)
 initial=wait(ready);assert initial['notes'][0]['title']=='Saved synthetic note',initial
 call('restoreTestBackup');saved=wait(lambda s:ready(s) and bool(s['state']['status'].get('lastBackupPath')))
 backup=saved['state']['status']['lastBackupPath'];assert Path(backup).stat().st_mode&0o777==0o600
 call('restoreTestChange');wait(lambda s:ready(s) and s['config']['textScale']==1.25)
 call('restoreTestPreview',backup);wait(lambda s:ready(s) and bool(s['preview']))
 before=json.loads(call('restoreTestState'))['pid'];call('restoreTestApply')
 restored=wait(lambda s:ready(s) and s['pid']!=before and bool(s['state']['status'].get('lastRestore')))
 assert restored['notes'][0]['body']=='Saved line one\nSaved line two',restored
 assert restored['config']['textScale']==1 and restored['config']['sidebarWidthPercent']==33,restored
 assert restored['config']['popupAppearance']['shadowSize']==28
 assert restored['config']['fontSizes']['notesBody']==18
 status=restored['state']['status'];safety=read(Path(status['safetyBackup']))
 assert safety['files']['notes'][0]['title']=='Current synthetic note'
 reading=home/'.config/starlink-dashboard/mail/omamail/window.json'
 assert not read(reading)['alwaysShowImages']
 assert not status.get('lastError'),status
 for name,light,narrow,settings in [('dark','false','false','false'),('light','true','false','false'),('narrow','false','true','false')]:
  image=root/(name+'.png');call('restoreTestVisual',light,narrow,settings);time.sleep(.7);call('restoreTestCapture',str(image),settings)
  deadline=time.monotonic()+5
  while not image.exists() and time.monotonic()<deadline:time.sleep(.1)
  assert image.exists(),name
 # Relaunch once more before exercising the failed restore.
 call('quit');wait_closed=time.monotonic()+10
 while config in subprocess.run(['quickshell','list','-a','-j'],env=env,capture_output=True,text=True).stdout and time.monotonic()<wait_closed:time.sleep(.1)
 subprocess.run([str(home/'.local/bin/stardock')],env=env,check=True,capture_output=True);wait(ready)
 # A test-only hook in the copied helper fails the second write after the first
 # has succeeded. The real handoff must roll back, report failure, and relaunch.
 call('restoreTestChange');wait(lambda s:ready(s) and s['config']['textScale']==1.25)
 call('restoreTestPreview',backup);wait(lambda s:ready(s) and bool(s['preview']))
 (home/'fail-restore-once').touch();before=json.loads(call('restoreTestState'))['pid'];call('restoreTestApply')
 failed=wait(lambda s:ready(s) and s['pid']!=before and bool(s['state']['status'].get('lastRestoreFailed')))
 assert 'Synthetic restore write failure' in failed['state']['status']['lastError'],failed
 assert failed['notes'][0]['title']=='Current synthetic note'
 assert failed['config']['textScale']==1.25 and failed['config']['sidebarWidthPercent']==25
 assert not list((home/'.local/state/starlink-dashboard/backups').glob('restore-*.json'))
 print('PASS: native backup, preview, save/quit, offline restore, safety snapshot, restart, multiline notes and appearance persistence; injected write failure rolls back and restarts; isolated profile only')
finally:
 try:call('quit')
 except subprocess.CalledProcessError:pass
 deadline=time.monotonic()+10
 while time.monotonic()<deadline:
  if config not in subprocess.run(['quickshell','list','-a','-j'],env=env,capture_output=True,text=True).stdout:break
  time.sleep(.1)
 else:subprocess.run(['quickshell','kill','-p',config],env=env,capture_output=True)
'''

def main():
    repo=Path(__file__).resolve().parents[1]
    if not shutil.which('bwrap'):raise SystemExit('Requires bubblewrap (bwrap)')
    with tempfile.TemporaryDirectory(prefix='stardock-restore-',dir='/tmp') as temporary:
        root=Path(temporary);source=root/'source';source.mkdir();profile=root/'profile';profile.mkdir()
        paths=subprocess.check_output(['git','ls-files','--cached','--others','--exclude-standard','-z'],cwd=repo).split(b'\0')
        for raw in paths:
            if not raw:continue
            relative=Path(raw.decode());original=repo/relative;target=source/relative
            target.parent.mkdir(parents=True,exist_ok=True)
            if original.is_symlink():target.symlink_to(original.readlink())
            else:shutil.copy2(original,target)
        shell=source/'shell.qml';text=shell.read_text();needle='    function backupStatus(): string'
        assert text.count(needle)==1;shell.write_text(text.replace(needle,IPC+needle))
        helper=source/'scripts/dashboard_backup.py';text=helper.read_text();needle='def private_write(path,data):\n'
        hook="    marker=Path.home()/'fail-restore-once'\n    if marker.exists() and path.name=='starlink-dashboard-notes.json':\n        marker.unlink();raise OSError('Synthetic restore write failure')\n"
        assert text.count(needle)==1;helper.write_text(text.replace(needle,needle+hook))
        config=profile/'.config';config.mkdir()
        (config/'starlink-dashboard-demo.json').write_text('{"enabledModules":["overview","weather","notes"],"mainPanel":"notes","rss":{"enabled":false,"feeds":[]},"popupAppearance":{"shadowSize":28},"fontSizes":{"notesBody":18}}')
        (config/'starlink-dashboard-notes.json').write_text('[{"title":"Saved synthetic note","body":"Saved line one\\nSaved line two","updated":1}]')
        reading=config/'starlink-dashboard/mail/omamail/window.json';reading.parent.mkdir(parents=True);reading.write_text('{"alwaysShowImages":true}')
        (root/'runner.py').write_text(RUNNER)
        subprocess.run(['bwrap','--ro-bind','/','/','--bind',str(profile),str(Path.home()),'--bind',str(root),str(root),'--dev-bind','/dev','/dev','--proc','/proc','--chdir',str(source),'/usr/bin/python3',str(root/'runner.py'),str(root)],check=True)
        for name in ('dark','light','narrow'):
            shutil.copy2(root/(name+'.png'),Path('/tmp')/('stardock-release-'+name+'.png'))

if __name__=='__main__':main()
