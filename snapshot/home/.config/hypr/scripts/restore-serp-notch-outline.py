#!/usr/bin/env python3
"""Restore the outline that follows the complete top-bar notch shape."""
from pathlib import Path
import sys

path = Path.home() / '.local/share/serpantinum/src/quickshell/bar/TopBar.qml'
outline = '''    // Local notch outline follows the shoulder curves and rounded lower edge.
    Shape {
        id: notchOutline
        x: solidBackground.x - contentWrapper.cornerRadius
        y: solidBackground.y
        width: solidBackground.width + 2 * contentWrapper.cornerRadius
        height: solidBackground.height
        visible: contentWrapper.isTopNotch && solidBackground.visible
        opacity: solidBackground.opacity
        z: 1
        layer.enabled: true
        layer.samples: 4
        readonly property bool trayAttached: TrayMenuController.isVisible && !TrayMenuController.isSideBar && !TrayMenuController.alignBottom && barWindow && TrayMenuController.screen === barWindow.screen
        readonly property real trayCenter: contentWrapper.mapFromItem(null, TrayMenuController.targetX, 0).x - x
        readonly property real outlineStart: contentWrapper.cornerRadius + solidBackground.radius
        readonly property real outlineEnd: contentWrapper.cornerRadius + solidBackground.width - solidBackground.radius
        readonly property real gapLeft: trayAttached ? Math.max(outlineStart, Math.min(outlineEnd, trayCenter - Scaler.s(236) / 2 - Scaler.s(12))) : outlineEnd
        readonly property real gapRight: trayAttached ? Math.max(gapLeft, Math.min(outlineEnd, trayCenter + Scaler.s(236) / 2 + Scaler.s(12))) : outlineEnd

        ShapePath {
            strokeWidth: 1
            strokeColor: Qt.alpha(ThemeBackend.text, 0.28)
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.RoundJoin
            startX: 0
            startY: 0
            PathQuad { x: contentWrapper.cornerRadius; y: contentWrapper.cornerRadius; controlX: contentWrapper.cornerRadius; controlY: 0 }
            PathLine { x: contentWrapper.cornerRadius; y: notchOutline.height - solidBackground.radius }
            PathQuad { x: contentWrapper.cornerRadius + solidBackground.radius; y: notchOutline.height - 0.5; controlX: contentWrapper.cornerRadius; controlY: notchOutline.height - 0.5 }
            PathLine { x: notchOutline.gapLeft; y: notchOutline.height - 0.5 }
            PathMove { x: notchOutline.gapRight; y: notchOutline.height - 0.5 }
            PathLine { x: contentWrapper.cornerRadius + solidBackground.width - solidBackground.radius; y: notchOutline.height - 0.5 }
            PathQuad { x: contentWrapper.cornerRadius + solidBackground.width; y: notchOutline.height - solidBackground.radius; controlX: contentWrapper.cornerRadius + solidBackground.width; controlY: notchOutline.height - 0.5 }
            PathLine { x: contentWrapper.cornerRadius + solidBackground.width; y: contentWrapper.cornerRadius }
            PathQuad { x: notchOutline.width; y: 0; controlX: contentWrapper.cornerRadius + solidBackground.width; controlY: 0 }
        }
    }

'''
try:
    source = path.read_text()
    updated = source
    if 'import QtQuick.Shapes\n' not in updated:
        needle = 'import QtQuick.Controls\n'
        if updated.count(needle) != 1: raise ValueError('imports changed')
        updated = updated.replace(needle, needle + 'import QtQuick.Shapes\n', 1)
    if outline not in updated:
        needle = '    ShaderEffect {\n        id: leftOuterCorner\n'
        if updated.count(needle) != 1: raise ValueError('notch layout changed')
        updated = updated.replace(needle, outline + needle, 1)
    if updated != source:
        path.write_text(updated)
        sys.exit(10)
    sys.exit(0)
except (OSError, ValueError) as exc:
    print(f'Serpantinum notch outline: {exc}', file=sys.stderr)
    sys.exit(1)
