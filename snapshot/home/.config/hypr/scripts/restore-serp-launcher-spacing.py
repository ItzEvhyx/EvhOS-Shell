#!/usr/bin/env python3
"""Restore launcher row spacing after Serpantinum updates."""
from pathlib import Path
import sys

path = Path.home() / '.local/share/serpantinum/src/quickshell/launcher/Launcher.qml'
try:
    source = path.read_text()
    old_row, new_row = 'launcherWindow.s(44)', 'launcherWindow.s(56)'
    old_height, new_height = '(count * s(48))', '(count * s(60))'
    if source.count(new_row) == 4 and source.count(new_height) == 1:
        sys.exit(0)
    if source.count(old_row) != 4 or source.count(old_height) != 1:
        raise ValueError('launcher layout changed; spacing needs manual review')
    path.write_text(source.replace(old_row, new_row).replace(old_height, new_height))
    sys.exit(10)
except (OSError, ValueError) as exc:
    print(f'Serpantinum launcher spacing: {exc}', file=sys.stderr)
    sys.exit(1)
