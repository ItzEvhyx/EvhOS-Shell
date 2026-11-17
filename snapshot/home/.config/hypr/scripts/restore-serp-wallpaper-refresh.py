#!/usr/bin/env python3
"""Restore the local-only wallpaper selector."""
from pathlib import Path
import sys
home = Path.home()
source = home / '.config/hypr/scripts/serpantinum-wallpaper-picker.qml'
target = home / '.local/share/serpantinum/src/quickshell/wallpaper/WallpaperPicker.qml'
helpers = home / '.local/share/serpantinum/src/scripts/wallpaper'
try:
    changed = False
    text = source.read_text()
    if not target.exists() or target.read_text() != text:
        target.write_text(text)
        changed = True
    for name in ('ddg_search.sh', 'get_ddg_links.py', 'search_control.sh', 'trigger_search.sh'):
        path = helpers / name
        if path.exists():
            path.unlink()
            changed = True
    sys.exit(10 if changed else 0)
except OSError as error:
    print(f'Local wallpaper selector restore: {error}', file=sys.stderr)
    sys.exit(1)
