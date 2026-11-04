#!/usr/bin/env python3
"""Reapply the floating dock and solid top bar pill styling after updates."""
import os
from pathlib import Path
import sys
import tempfile

base = Path.home() / '.local/share/serpantinum/src/quickshell'
changes = {
    base / 'bar/TopBar.qml': [
        ('NumberAnimation { duration: 250; easing.type: Easing.OutQuint }\n        }\n    }\n\n    Behavior on opacity {\n        enabled: barWindow ? (!barWindow.positionChanging && barWindow.startupCascadeFinished) : true\n        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }',
         'NumberAnimation { duration: 80; easing.type: Easing.OutQuint }\n        }\n    }\n\n    Behavior on opacity {\n        enabled: barWindow ? (!barWindow.positionChanging && barWindow.startupCascadeFinished) : true\n        NumberAnimation { duration: 80; easing.type: Easing.OutCubic }'),
        ('        radius: isFill ? 0 : ThemeBackend.borderRadius',
         '        radius: isFill ? 0 : height / 2 // local pill style'),
        ('    property real distinctEdgePadding: (isSolid && distinctPills) ? (barWindow ? barWindow.s(4) : 4) : 4',
         '    property real distinctEdgePadding: isSolid && !isFill ? (barWindow ? barWindow.s(14) : 14) : 4 // local pill padding'),
    ],
    base / 'dock/DockContainer.qml': [
        ('duration: dockWindow.isRevealed ? 240 : 180', 'duration: 80 // local fast workspace transition'),
        ('NumberAnimation { duration: 280; easing.type: Easing.OutQuint }', 'NumberAnimation { duration: 80; easing.type: Easing.OutQuint } // local fast workspace transition'),
        ('        ? ThemeBackend.borderRadius\n        : Math.max(0, Math.min(dockWindow.outerCornerRadius, (dockWindow.isVertical ? width : height) * 0.5))',
         '        ? (dockWindow.isVertical ? width : height) / 2 // local pill style\n        : Math.max(0, Math.min(dockWindow.outerCornerRadius, (dockWindow.isVertical ? width : height) * 0.5))'),
        ('    property real fullContentLength: dockContentLength + dockWindow.s(20)',
         '    property real fullContentLength: dockContentLength + dockWindow.s(dockWindow.dockFloating ? 44 : 20) // local pill padding'),
    ],
}
try:
    pending = []
    for path, replacements in changes.items():
        old = path.read_text()
        updated = old
        for before, after in replacements:
            if after in updated:
                continue
            if before.startswith('NumberAnimation { duration: 280;') and updated.count(before) == 2:
                updated = updated.replace(before, after)
                continue
            if updated.count(before) != 1:
                raise ValueError(f'{path.name} layout changed; pill style needs manual review')
            updated = updated.replace(before, after, 1)
        if updated != old:
            pending.append((path, updated))
    for path, content in pending:
        fd, temp = tempfile.mkstemp(prefix='.' + path.stem + '.', suffix='.qml', dir=path.parent)
        try:
            with os.fdopen(fd, 'w') as f: f.write(content)
            os.chmod(temp, path.stat().st_mode & 0o777)
            os.replace(temp, path)
        finally:
            if os.path.exists(temp): os.unlink(temp)
    sys.exit(10 if pending else 0)
except (OSError, ValueError) as exc:
    print(f'Serpantinum pill style: {exc}', file=sys.stderr)
    sys.exit(1)
