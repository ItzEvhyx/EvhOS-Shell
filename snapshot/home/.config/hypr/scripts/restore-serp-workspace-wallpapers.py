#!/usr/bin/env python3
"""Restore active wallpaper previews in the workspace overview."""
from pathlib import Path
import sys
home = Path.home()
base = home / '.local/share/serpantinum/src/quickshell'
saved = home / '.config/hypr/scripts/serpantinum-workspace-wallpapers'
try:
    changed = False
    for relative in ('overview/WorkspaceCard.qml', 'overview/WorkspaceGrid.qml',
                     'overview/WorkspaceWallpaperSource.qml', 'wallpaper/WallpaperEngine.qml'):
        source = saved / relative
        target = base / relative
        text = source.read_text()
        if not target.exists() or target.read_text() != text:
            target.write_text(text)
            changed = True
    registry = base / 'qmldir'
    entry = 'WorkspaceWallpaperSource 1.0 overview/WorkspaceWallpaperSource.qml\n'
    text = registry.read_text()
    if entry not in text:
        registry.write_text(text.rstrip() + '\n' + entry)
        changed = True
    sys.exit(10 if changed else 0)
except OSError as error:
    print(f'Workspace wallpaper restore: {error}', file=sys.stderr)
    sys.exit(1)
