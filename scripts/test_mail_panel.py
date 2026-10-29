#!/usr/bin/python3
"""Desktop integration tests using only the synthetic MailFixture service."""
import json
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
CONFIG = str(ROOT/'mail-panel-test.qml')
BASE = ['quickshell', 'ipc', '-p', CONFIG, 'call', 'mailtest']

def call(method, *args):
    result = subprocess.check_output(BASE+[method, *args], text=True).strip()
    if result.startswith('FAIL'):
        raise AssertionError(result)
    return result

def settle():
    time.sleep(.4)

def main():
    subprocess.run(['quickshell','kill','-p',CONFIG],capture_output=True)
    for _ in range(40):
        if CONFIG not in subprocess.run(['quickshell','list','-a','-j'],capture_output=True,text=True).stdout: break
        time.sleep(.1)
    subprocess.run(['quickshell','-n','-d','-p',CONFIG],capture_output=True,check=True)
    try:
        settle()
        assert call("verifyInitialMessage").startswith("PASS")
        assert call("verifyStyle").startswith("PASS")
        assert call("verifyPopupAppearance").startswith("PASS")
        call("seedUnsubscribe"); settle()
        assert call("verifyUnsubscribeToolbar").startswith("PASS")
        for mode in ['reply', 'replyAll', 'forward']:
            call('compose',mode); settle()
            draft = json.loads(call('inspectCompose'))['draft']
            assert draft['mode'] == mode and draft['accountId'] == 'fixture'
            if mode != 'forward':
                assert draft['to'] == 'sender@example.test'
                assert draft['threadId'] == 'fixture-thread'
                assert draft['inReplyTo'] == '<fixture-id@example.test>'
                assert draft['cc'] == ('copy@example.test' if mode == 'replyAll' else '')
        call('prepare'); settle()
        call('flush'); settle()
        assert call('flushStatus').startswith('PASS')
        call('recreate'); settle()
        assert call('verifyRecovery').startswith('PASS')
        assert call('send').startswith('PASS'); settle()
        call('undo'); settle()
        assert call('verifyUndo').startswith('PASS')
        call('saveDraft','false'); settle()
        assert call('verifySave','false').startswith('PASS')
        call('prepare'); settle()
        call('saveDraft','true'); settle()
        assert call('verifySave','true').startswith('PASS')
        call('forwardSend'); settle()
        assert call('verifyForwardSend').startswith('PASS'); settle()
        assert call('actions').startswith('PASS'); settle()
        assert call('verifyRestore').startswith('PASS')
        call('prepare'); settle()
        assert call('send').startswith('PASS'); settle()
        call('newerDraft'); settle()
        call('undo'); settle()
        assert call('verifyBothDrafts').startswith('PASS')
        call('recreate'); settle()
        assert call('verifyRecovery').startswith('PASS')
        assert call('finishRecoveredOriginal').startswith('PASS')
        call('prepare'); settle()
        assert call('send').startswith('PASS'); settle()
        call('alreadySent')
        call('recreate'); settle()
        assert call('verifyNoResend').startswith('PASS')
        print('PASS: mail composition, recipients, threading, attachments, drafts, recovery, send/undo, delivery receipts and mailbox actions (synthetic service only)')
    finally:
        subprocess.run(['quickshell','kill','-p',CONFIG],capture_output=True)

if __name__ == '__main__':
    main()
