#!/usr/bin/python3
"""Exercise native calendar UI with synthetic events; no network or real credentials."""
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONFIG = str(ROOT / 'calendar-panel-test.qml')
BASE = ['quickshell', 'ipc', '-p', CONFIG, 'call', 'calendartest']


def call(method, *args):
    result = subprocess.check_output(BASE + [method, *args], text=True).strip()
    assert result.startswith('PASS'), result


def main():
    subprocess.run(['quickshell', 'kill', '-p', CONFIG], capture_output=True)
    for _ in range(40):
        if CONFIG not in subprocess.run(['quickshell', 'list', '-a', '-j'], capture_output=True, text=True).stdout:
            break
        time.sleep(.1)
    subprocess.run(['quickshell', '-n', '-d', '-p', CONFIG], capture_output=True, check=True)
    try:
        for mode in ['month', 'week', 'day', 'agenda']:
            call('view', mode)
        call('details')
        time.sleep(.3)
        call('verify')
        call('newEvent')
        call('invalidDate')
        call('prepare','false')
        call('save','true')
        time.sleep(.2)
        call('verifySave','true')
        call('save','false')
        time.sleep(.2)
        call('verifySave','false')
        call('edit')
        call('save','false')
        time.sleep(.2)
        call('verifySave','false')
        call('verifyUpdate')
        call('newEvent')
        call('prepare','true')
        call('recurrence')
        call('save','false')
        time.sleep(.2)
        call('verifySave','false')
        call('verifyAllDay')
        call('deleteEvent')
        call('verifyDeletePrompt')
        call('deleteEvent')
        call('confirmDelete')
        call('undo')
        call('reschedule')
        call('leaveGuard')
        call('defaultCalendar')
        call('readOnly')
        call('preferences')
        call('reminder','open','false')
        for action, fail in [('snooze','true'),('snooze','false'),('dismiss','false')]:
            call('reminder',action,fail)
            time.sleep(.2)
            call('verifyReminder',fail)
        call('connections')
        call('closeConnections')
        print('PASS: native month/week/day/agenda, event details, creation, editing, all-day events, failure recovery, delete confirmation, undo, read-only controls, preferences and reminder open/snooze/dismiss (synthetic events only)')
    finally:
        subprocess.run(['quickshell', 'kill', '-p', CONFIG], capture_output=True)


if __name__ == '__main__':
    main()
