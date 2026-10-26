#!/bin/sh
# Install StarDock launchers; account data and the private backend stay separate.
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
command -v quickshell >/dev/null
test -d /usr/share/omarchy/shell/Commons
test -d /usr/share/omarchy/shell/Ui
python3 - "$project_dir" <<'PY'
from pathlib import Path
import shlex
import sys

root = Path(sys.argv[1])
home = Path.home()
for name in ('Commons', 'Ui'):
    target = root/name
    if not target.exists() and not target.is_symlink():
        target.symlink_to('/usr/share/omarchy/shell/'+name)
launcher = home/'.local/bin/stardock'
launcher.parent.mkdir(parents=True, exist_ok=True)
launcher.write_text('#!/bin/sh\nconfig='+shlex.quote(str(root/'shell.qml'))+'\n'
    'if quickshell ipc -p "$config" call dashboard show >/dev/null 2>&1; then exit 0; fi\n'
    'exec quickshell -n -d -p "$config" "$@"\n')
launcher.chmod(0o755)
desktop = home/'.local/share/applications/stardock.desktop'
desktop.parent.mkdir(parents=True, exist_ok=True)
exec_path = str(launcher).replace('\\', '\\\\').replace('"', '\\"').replace('`', '\\`').replace('$', '\\$').replace('%', '%%')
desktop.write_text('[Desktop Entry]\nType=Application\nName=StarDock\n'
    'Comment=Mail, calendar, notes, weather and news dashboard\n'
    'Exec="'+exec_path+'"\nIcon=view-grid-symbolic\nTerminal=false\n'
    'Categories=Utility;\nStartupNotify=false\n')
print('StarDock launcher installed. See README.md for the pinned mail backend setup.')
PY
