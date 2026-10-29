#!/usr/bin/python3
"""Private, credential-free dashboard snapshots and offline restore handoff."""
import contextlib
import datetime as dt
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile
import time
import uuid
from urllib.parse import urlsplit

FORMAT='starlink-dashboard-backup'
LIMIT=32*1024*1024
NAMES={'dashboard':'starlink-dashboard-demo.json','notes':'starlink-dashboard-notes.json',
       'preferences':'starlink-dashboard/mail/omamail/dashboard.json',
       'reading':'starlink-dashboard/mail/omamail/window.json',
       'calendars':'starlink-dashboard/mail/omamail/calendars.json',
       'accounts':'starlink-dashboard/mail/omamail/accounts.json'}
LABELS={'dashboard':'Dashboard, appearance, weather, modules and RSS','notes':'Notes',
        'preferences':'Account and calendar preferences','reading':'Mail reading preferences',
        'calendars':'Calendar sources','accounts':'Names, signatures and monitored folders of matching accounts'}
PREFS=set('refreshIntervalSec maxMessages heavyMessageRendering contentDirection appearance defaultQuery notifyNewMail oauthPort undoSendSeconds unifiedCalendarView calendarRemindersEnabled calendarSnoozeMinutes showBarIcon unifiedMailboxes suggestEvents calendarDefaultView calendarWeekStart calendarDuration calendarTimeZone calendarTimeFormat calendarDateFormat calendarDisplayTimePattern'.split())
WINDOW=set('sidebarCollapsed sidebarWidth listWidth collapsedFolders bodyZoom bodyMode alwaysShowImages'.split())
CALENDAR=set('id kind name url username accountId enabled calendarId readOnly discovered colorKey accessRole timeZone canCreateMeet defaultReminders remindersEnabled reminderMinutes preferred'.split())
ACCOUNT=set('id label senderName signature signatureHtml monitored'.split())
DASHBOARD=set('popupAppearance fontSizes sidebarWidthPercent enabledModules fullscreenTitleSize clock colors textScale mainPanel rss popupWidthPercent weather overview'.split())

def now():return dt.datetime.now(dt.timezone.utc).isoformat()
def encode(value):return (json.dumps(value,ensure_ascii=False,indent=2)+'\n').encode()
def read_bytes(path):
    fd=os.open(path,os.O_RDONLY|os.O_NOFOLLOW)
    try:
        if not stat.S_ISREG(os.fstat(fd).st_mode):raise ValueError('Expected a regular JSON file')
        with os.fdopen(fd,'rb',closefd=False) as stream:data=stream.read(LIMIT+1)
        if len(data)>LIMIT:raise ValueError('JSON file is too large')
        return data
    finally:os.close(fd)
def read_json(path):return json.loads(read_bytes(path))
def private_write(path,data):
    for parent in [path.parent,*path.parent.parents]:
        if parent.is_symlink():raise ValueError('Symbolic links cannot be restore destinations')
    if path.is_symlink():raise ValueError('Symbolic links cannot be restore destinations')
    path.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
    fd,tmp=tempfile.mkstemp(prefix='.starlink-',dir=path.parent)
    try:
        with os.fdopen(fd,'wb') as stream:stream.write(data);stream.flush();os.fsync(stream.fileno())
        os.replace(tmp,path)
    finally:
        if os.path.exists(tmp):os.unlink(tmp)
def pick(value,keys):
    if not isinstance(value,dict):raise ValueError('Expected an object')
    return {key:value[key] for key in keys if key in value}
def clean_url(value):
    if not isinstance(value,str) or any(ord(c)<32 for c in value):return ''
    try:
        url=urlsplit(value)
        if url.scheme not in ('http','https') or not url.hostname or url.username or url.password or url.query or url.fragment:return ''
        return value
    except ValueError:return ''

def sanitize(key,value):
    """Never serialize whole account registries, credential stores or unknown fields."""
    if key=='notes':
        if not isinstance(value,list) or len(value)>100000:raise ValueError('Invalid notes list')
        out=[]
        for item in value:
            item=pick(item,{'title','body','updated'})
            if not isinstance(item.get('title',''),str) or not isinstance(item.get('body',''),str):raise ValueError('Invalid note text')
            out.append(item)
        return out
    if key=='dashboard':
        out=pick(value,DASHBOARD)
        if 'rss' in out:
            rss=pick(out['rss'],{'enabled','feeds','scrollSpeed','maxWords'})
            rss['feeds']=[{'url':clean_url(feed.get('url')),'count':feed.get('count',10)} for feed in rss.get('feeds',[]) if isinstance(feed,dict) and clean_url(feed.get('url'))]
            out['rss']=rss
        if 'popupAppearance' in out:out['popupAppearance']=pick(out['popupAppearance'],{'shadowSize','shadowColor','overlayOpacity'})
        if 'fontSizes' in out:out['fontSizes']={k:v for k,v in pick(out['fontSizes'],{'emailBody','notesBody','summaries','rssBody','rssHeadline'}).items() if type(v) in (int,float) and 0<v<=100}
        if 'colors' in out:out['colors']=pick(out['colors'],{'background','foreground','accent'})
        if 'clock' in out:out['clock']=pick(out['clock'],{'fontSize','hourFormat','dateFormat'})
        if 'weather' in out:out['weather']=pick(out['weather'],set('location latitude longitude countryCode temperatureUnit units refreshMinutes mapZoom'.split()))
        if 'overview' in out:out['overview']=pick(out['overview'],{'order','hidden'})
        return out
    if key=='preferences':return pick(value,PREFS)
    if key=='reading':return pick(value,WINDOW)
    if key=='calendars':
        if not isinstance(value,dict) or not isinstance(value.get('sources'),list):raise ValueError('Invalid calendar sources')
        sources=[]
        for source in value['sources']:
            entry=pick(source,CALENDAR)
            if entry.get('url') and not clean_url(entry['url']):continue
            if 'defaultReminders' in entry:entry['defaultReminders']=[pick(r,{'method','minutes'}) for r in entry['defaultReminders'] if isinstance(r,dict)]
            sources.append(entry)
        return {'version':1,'sources':sources}
    if key=='accounts':
        if not isinstance(value,dict) or not isinstance(value.get('accounts'),list):raise ValueError('Invalid account preferences')
        return {'accounts':[pick(item,ACCOUNT) for item in value['accounts'] if isinstance(item,dict) and item.get('id')]}
    raise ValueError('Unsupported backup section')

class Backups:
    def __init__(self,home=None):
        self.home=Path(home) if home else Path.home()
        self.config=self.home/'.config'
        self.state=self.home/'.local/state/starlink-dashboard/backups'
        self.settings_path=self.config/'starlink-dashboard-backups.json'
        self.status_path=self.state/'status.json'
    def target(self,key):return self.config/NAMES[key]
    @contextlib.contextmanager
    def locked(self):
        self.state.mkdir(parents=True,exist_ok=True,mode=0o700)
        fd=os.open(self.state/'operation.lock',os.O_CREAT|os.O_RDWR|os.O_NOFOLLOW,0o600)
        try:fcntl.flock(fd,fcntl.LOCK_EX);yield
        finally:os.close(fd)
    def settings(self):
        default={'directory':str(self.home/'.local/share/starlink-dashboard/backups'),'schedule':'off','keep':10}
        if self.settings_path.exists():default.update(pick(read_json(self.settings_path),set(default)))
        return self.normalize_settings(default)
    def normalize_settings(self,value):
        directory=Path(str(value.get('directory',''))).expanduser()
        if not directory.is_absolute() or str(directory)=='/':raise ValueError('Choose an absolute backup folder path')
        keep=int(value.get('keep',10))
        return {'directory':str(directory),'schedule':value.get('schedule') if value.get('schedule') in ('off','daily','weekly') else 'off','keep':max(1,min(365,keep))}
    def status(self):
        try:return read_json(self.status_path) if self.status_path.exists() else {}
        except (ValueError,OSError):return {}
    def record(self,**values):
        value=self.status();value.update(values);private_write(self.status_path,encode(value))
    def snapshot(self,live=None):
        files={}
        for key in NAMES:
            if key in (live or {}) and key in ("dashboard","notes"):
                files[key]=sanitize(key,live[key]);continue
            path=self.target(key)
            if path.exists():files[key]=sanitize(key,read_json(path))
        return {'format':FORMAT,'version':1,'createdAt':now(),'files':files}
    def create(self,kind='manual',live=None):
        settings=self.settings();directory=Path(settings['directory']).resolve()
        directory.mkdir(parents=True,exist_ok=True,mode=0o700)
        value=self.snapshot(live);value['kind']=kind
        path=directory/('starlink-backup-'+dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')+'-'+uuid.uuid4().hex[:8]+'.json')
        content=encode(value)
        if len(content)>LIMIT:raise ValueError('Combined backup exceeds the 32 MiB limit')
        private_write(path,content)
        self.record(lastBackup=now(),lastBackupPath=str(path),lastError='')
        self.prune(directory,settings['keep'])
        return str(path)
    def list(self):
        directory=Path(self.settings()['directory']).resolve()
        out=[]
        if directory.is_dir():
            for path in directory.glob('starlink-backup-*.json'):
                try:
                    value=read_json(path)
                    if value.get('format')!=FORMAT or value.get('version')!=1:continue
                    out.append({'path':str(path),'createdAt':str(value.get('createdAt','')),'kind':str(value.get('kind','manual')),'bytes':path.stat().st_size})
                except (ValueError,OSError,AttributeError,TypeError):continue
        return sorted(out,key=lambda v:v['path'],reverse=True)
    def prune(self,directory,keep):
        # Only regular snapshots of this format in the chosen folder are eligible.
        for entry in self.list()[keep:]:
            path=Path(entry['path'])
            if path.parent==directory and not path.is_symlink():path.unlink()
    def preview(self,path):
        path=Path(path).expanduser().absolute()
        raw=read_bytes(path);value=json.loads(raw)
        if not isinstance(value,dict) or value.get('format')!=FORMAT or value.get('version')!=1 or not isinstance(value.get('files'),dict):raise ValueError('Not a supported StarDock backup')
        if set(value['files'])-set(NAMES):raise ValueError('Backup contains unsupported sections')
        files={key:sanitize(key,data) for key,data in value['files'].items()}
        if not files:raise ValueError('Backup is empty')
        digest=hashlib.sha256(raw).hexdigest()
        notes=len(files.get('notes',[]));sources=len(files.get('calendars',{}).get('sources',[]))
        return {'path':str(path),'digest':digest,'createdAt':value.get('createdAt','Unknown'),'sections':[LABELS[k] for k in files],
                'notes':notes,'calendars':sources,'accountPreferences':len(files.get('accounts',{}).get('accounts',[])),
                'files':files}
    def stage(self,path,digest):
        preview=self.preview(path)
        if preview['digest']!=digest:raise ValueError('Backup changed. Preview it again before restoring')
        ticket=self.state/('restore-'+uuid.uuid4().hex+'.json')
        private_write(ticket,encode({'path':preview['path'],'digest':digest}))
        return str(ticket)
    @contextlib.contextmanager
    def account_locked(self):
        directory=self.target('accounts').parent
        if not directory.exists():yield;return
        for parent in [directory,*directory.parents]:
            if parent.is_symlink():raise ValueError('Account directory is a symbolic link')
        fd=os.open(directory/'.accounts.lock',os.O_CREAT|os.O_RDWR|os.O_NOFOLLOW,0o600)
        try:fcntl.flock(fd,fcntl.LOCK_EX);yield
        finally:os.close(fd)
    def restore(self,path,digest):
        with self.account_locked():return self._restore(path,digest)
    def _restore(self,path,digest):
        preview=self.preview(path)
        if preview['digest']!=digest:raise ValueError('Backup changed. Preview it again before restoring')
        files=preview['files'];writes={}
        for key,value in files.items():
            if key=='accounts':
                target=self.target(key)
                if not target.exists():continue
                existing=read_json(target)
                saved={p['id']:p for p in value['accounts']}
                for entry in existing.get('accounts',[]):
                    if entry.get('id') in saved:
                        entry.update({k:v for k,v in saved[entry['id']].items() if k!='id'})
                value=existing
            if key=='reading':value=dict(value,alwaysShowImages=False,windowOpen=False)
            content=encode(value)
            if key=='accounts' and len(content)>1024*1024:raise ValueError('Restored account preferences exceed the account registry limit')
            writes[self.target(key)]=content
        for path in writes:
            if path.is_symlink():raise ValueError('Restore destination is a symbolic link')
            for parent in [path.parent,*path.parent.parents]:
                if parent.is_symlink():raise ValueError('Restore destination contains a symbolic link')
        safety=self.create('before-restore')
        originals={p:p.read_bytes() if p.exists() else None for p in writes}
        changed=[]
        try:
            for target,content in writes.items():private_write(target,content);changed.append(target)
        except Exception:
            for target in reversed(changed):
                if originals[target] is None:target.unlink(missing_ok=True)
                else:private_write(target,originals[target])
            raise
        self.record(lastRestore=now(),lastRestoreBackup=preview['path'],safetyBackup=safety,lastError='')
        return {'safetyBackup':safety,'restored':len(changed)}
    def due(self):
        setting=self.settings();schedule=setting['schedule']
        if schedule=='off':return False
        last=self.status().get('lastBackup','')
        try:elapsed=(dt.datetime.now(dt.timezone.utc)-dt.datetime.fromisoformat(last)).total_seconds()
        except (ValueError,TypeError):return True
        return elapsed>=(86400 if schedule=='daily' else 604800)
    def run(self,request):
        operation=request.get('op','status')
        with self.locked():
            extra={}
            if operation=='configure':private_write(self.settings_path,encode(self.normalize_settings(request['settings'])))
            elif operation=='backup':extra['created']=self.create(live=request.get('live'))
            elif operation=='scheduled' and self.due():extra['created']=self.create('scheduled',request.get('live'))
            elif operation=='preview':
                extra['preview']=self.preview(request['path']);extra['preview'].pop('files')
            elif operation=='stage':extra['ticket']=self.stage(request['path'],request['digest'])
            elif operation not in ('status','scheduled'):raise ValueError('Unknown backup operation')
            return dict(ok=True,settings=self.settings(),status=self.status(),backups=self.list(),**extra)

def finish_restore(ticket,pid):
    manager=Backups()
    ticket=Path(ticket)
    if ticket.parent!=manager.state or not re.fullmatch(r'restore-[0-9a-f]{32}\.json',ticket.name):raise ValueError('Invalid restore ticket')
    try:
        request=read_json(ticket)
        deadline=time.monotonic()+30
        while (Path('/proc')/str(pid)).exists():
            if time.monotonic()>deadline:raise ValueError('Dashboard did not close. No settings were restored')
            time.sleep(.1)
        # A second dashboard instance must not write while files are restored.
        running=subprocess.run(['quickshell','list','-a','-j'],capture_output=True,text=True,timeout=5)
        config=str(Path(__file__).resolve().parents[1]/'shell.qml')
        if running.returncode!=0 or config in running.stdout:raise ValueError('Dashboard is running. Close it before restoring')
        with manager.locked():manager.restore(request['path'],request['digest'])
    except Exception as error:
        manager.record(lastError=str(error),lastRestoreFailed=now())
    finally:
        ticket.unlink(missing_ok=True)
        subprocess.Popen([str(manager.home/'.local/bin/stardock')],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,start_new_session=True)

if __name__=='__main__':
    if len(sys.argv)==4 and sys.argv[1]=='--finish-restore':
        finish_restore(sys.argv[2],int(sys.argv[3]))
    else:
        manager=Backups()
        try:
            request=json.load(sys.stdin)
            result=manager.run(request)
        except Exception as error:
            result={'ok':False,'error':str(error)}
            try:manager.record(lastError=str(error))
            except Exception:pass
        print(json.dumps(result))
