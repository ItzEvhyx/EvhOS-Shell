#!/usr/bin/env python3
"""Keep the solid top bar attached to the screen with notch-shaped corners."""
from pathlib import Path
import sys

base = Path.home() / '.local/share/serpantinum/src/quickshell/bar'
changes = {
    base / 'Bar.qml': [
        ('            property real edgePadding: (autohide && !isFill) ? s(4) : 0',
         '            property real edgePadding: (barPosition === "top" && barStyle === "solid") ? 0 : ((autohide && !isFill) ? s(4) : 0) // local notch'),
        ('                top: isFill ? 0 : (barPosition === "bottom" ? 0 : (autohide ? 0 : s(4)))',
         '                top: (isFill || (barPosition === "top" && barStyle === "solid")) ? 0 : (barPosition === "bottom" ? 0 : (autohide ? 0 : s(4))) // local notch'),
    ],
    base / 'TopBar.qml': [
        ('    property real fillAttachProgress: (isFill && barWindow && barWindow.fillAttached) ? 1.0 : 0.0',
         '    property bool isTopNotch: isSolid && !isFill && !!barWindow && barWindow.barPosition === "top" // local notch\n    property real fillAttachProgress: ((isFill && barWindow && barWindow.fillAttached) || isTopNotch) ? 1.0 : 0.0'),
        ('        topLeftRadius: isFill ? (contentWrapper.barAtBottom ? contentWrapper.fillFarRadius : 0) : radius',
         '        topLeftRadius: contentWrapper.isTopNotch ? 0 : (isFill ? (contentWrapper.barAtBottom ? contentWrapper.fillFarRadius : 0) : radius) // local notch'),
        ('        topRightRadius: isFill ? (contentWrapper.barAtBottom ? contentWrapper.fillFarRadius : 0) : radius',
         '        topRightRadius: contentWrapper.isTopNotch ? 0 : (isFill ? (contentWrapper.barAtBottom ? contentWrapper.fillFarRadius : 0) : radius) // local notch'),
        ('visible: !ThemeBackend.liquidGlass && contentWrapper.isFill && radius > 0.5 && (barWindow ? !barWindow.positionChanging : true)',
         'visible: !ThemeBackend.liquidGlass && (contentWrapper.isFill || contentWrapper.isTopNotch) && radius > 0.5 && (barWindow ? !barWindow.positionChanging : true) // local notch'),
    ],
}
try:
    pending = []
    for path, edits in changes.items():
        source = path.read_text()
        updated = source
        for old, new in edits:
            if old.startswith('    property real fillAttachProgress:') and '    property bool isTopNotch:' in updated and '|| isTopNotch) ? 1.0 : 0.0' in updated:
                continue
            expected = 2 if old.startswith('visible: !ThemeBackend.liquidGlass') else 1
            if updated.count(new) == expected: continue
            if updated.count(old) != expected: raise ValueError(f'{path.name} layout changed; notch needs review')
            updated = updated.replace(old, new)
        if updated != source: pending.append((path, updated))
    for path, updated in pending: path.write_text(updated)
    sys.exit(10 if pending else 0)
except (OSError, ValueError) as exc:
    print(f'Serpantinum notch: {exc}', file=sys.stderr)
    sys.exit(1)
