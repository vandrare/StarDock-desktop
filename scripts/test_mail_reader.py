#!/usr/bin/python3
"""Synthetic rich-mail integration and loopback resource-leak regression checks."""
import http.server
import json
from pathlib import Path
import subprocess
import threading
import time

ROOT=Path(__file__).resolve().parents[1]
CONFIG=str(ROOT/'mail-panel-test.qml')
BASE=['quickshell','ipc','-p',CONFIG,'call','mailtest']

class ResourceTrap(http.server.BaseHTTPRequestHandler):
    requests=[]
    def do_GET(self):
        self.requests.append(self.path)
        self.send_response(200);self.end_headers()
        self.wfile.write(b'forbidden resource')
    def log_message(self,*args): pass

def call(method,*args):
    output=subprocess.check_output(BASE+[method,*args],text=True).strip()
    assert not output.startswith('FAIL'),output
    return output

def state():
    time.sleep(.15)
    return json.loads(call('readerState'))

def main():
    server=http.server.ThreadingHTTPServer(('127.0.0.1',0),ResourceTrap)
    thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
    port=server.server_port
    subprocess.run(['quickshell','kill','-p',CONFIG],capture_output=True)
    for _ in range(40):
        if CONFIG not in subprocess.run(['quickshell','list','-a','-j'],capture_output=True,text=True).stdout:break
        time.sleep(.1)
    subprocess.run(['quickshell','-n','-d','-p',CONFIG],capture_output=True,check=True)
    try:
        html=f'''<h1>Reader test</h1><p>First paragraph</p><p>Second paragraph</p>
        <table bgcolor="#ffeecc"><tr><td><b>Formatted content</b></td></tr></table>
        <img src="https://images.example.com/banner.png" width="640" height="360">
        <img src="http://127.0.0.1:{port}/image"><body background="http://127.0.0.1:{port}/background">
        <iframe src="http://127.0.0.1:{port}/frame"></iframe>
        <img src="file:///tmp/forbidden-mail-image.png"><script>alert('no')</script>
        <a href="javascript:alert(1)">Unsafe link</a><a href="https://example.com/article">Safe link</a>'''
        call('html',html)
        current=state()
        assert current['fontSize']==current['titleFont']==12,current
        assert current['mode']=='reader' and current['rich'] and current['blocked']>=1,current
        assert not current['allowed'] and not current['always'] and current['approvals']==0
        for mode in ['original','plain','reader']:
            call('readerMode',mode)
            current=state()
            assert current['mode']==mode,current
            assert '<script' not in current['body'] and 'file:///' not in current['body']
            assert f'127.0.0.1:{port}' not in current['body']
            assert not ResourceTrap.requests,ResourceTrap.requests
        call('approveImages')
        current=state()
        assert current['allowed'] and not current['always'] and current['approvals']==1
        call('html',html)
        assert not state()['allowed'],'Image consent leaked to the next message'
        call('heavy','true')
        assert state()['mode']=='plain','Heavy message did not fall back to plain text'
        call('heavy','false')
        for url in ['javascript:alert(1)','file:///etc/passwd',f'http://127.0.0.1:{port}/clicked']:
            call('readerLink',url)
        assert not state()['links'],'Unsafe link escaped the reader'
        call('readerLink','https://example.com/article')
        assert state()['links']==['https://example.com/article']
        call('readerLink','mailto:person@example.test?subject=Reader%20test&body=First%0ASecond')
        draft=json.loads(call('inspectCompose'))['draft']
        assert draft['to']=='person@example.test' and draft['subject']=='Reader test',draft
        assert 'First\nSecond' in draft['body'],draft
        call('readerLink','mailto:other@example.test?subject=Do%20not%20overwrite')
        retained=json.loads(call('inspectCompose'))['draft']
        assert retained['to']==draft['to'] and retained['subject']==draft['subject'],'Mailto link overwrote an open draft'
        assert state()['sent']==0,'A mailto link sent mail'
        call('closeCompose')
        call('html','')
        assert state()['mode']=='plain','Text-only mail did not use plain fallback'
        assert not ResourceTrap.requests,ResourceTrap.requests
        call('clearReader');time.sleep(.15);call('verifyEmptyReader')
        print('PASS: reading/formatted/plain modes, blocked resources, per-message image consent, heavy/text fallbacks, checked links and unsent mailto drafts; zero loopback resource requests')
    finally:
        subprocess.run(['quickshell','kill','-p',CONFIG],capture_output=True)
        server.shutdown();server.server_close()

if __name__=='__main__':main()
