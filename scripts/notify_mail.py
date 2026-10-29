#!/usr/bin/python3
"""Send a StarDock notification with sender-authored text kept out of options."""
from html import escape
import json
import os
import sys


def command(value):
    if not isinstance(value,dict):raise ValueError('Expected a notification')
    fields=[]
    for key in ('title','body'):
        text=value.get(key,'')
        if not isinstance(text,str) or '\0' in text:raise ValueError('Invalid notification text')
        fields.append(escape(text[:10000],quote=False))
    return ['notify-send','--app-name=StarDock','--icon=mail-unread',
            '--expire-time=10000','--action=default=Read…','--',*fields]


if __name__=='__main__':
    try:
        payload=sys.stdin.read(65537)
        if len(payload)>65536:raise ValueError('Notification too large')
        args=command(json.loads(payload))
        os.execvp(args[0],args)
    except Exception:
        print('Could not send mail notification',file=sys.stderr)
        sys.exit(1)
