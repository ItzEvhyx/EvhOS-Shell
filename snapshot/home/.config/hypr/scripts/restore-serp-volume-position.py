#!/usr/bin/env python3
"""Restore volume-panel alignment with the bar button after shell updates."""
from pathlib import Path
import sys
base = Path.home() / '.local/share/serpantinum/src/quickshell'
helper = '    function openVolumePanel() {\n        if (root.isPreview) return;\n        if (root.barWindow && !root.isVertical) {\n            let point = root.mapToItem(null, 0, 0);\n            OsdController.volumePanelAnchor = {\n                screen: root.barWindow.screen,\n                centerX: point.x + root.width / 2,\n                minX: root.barWindow.currentBarMinX,\n                maxX: root.barWindow.currentBarMaxX\n            };\n        } else {\n            OsdController.volumePanelAnchor = null;\n        }\n        Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle volume"]);\n    }\n\n'
block = '        // Align the volume panel with the bar button, keeping it inside the bar.\n        let volumeAnchor = OsdController.volumePanelAnchor;\n        if (name === "volume" && (bp === "top" || bp === "bottom") && volumeAnchor\n                && volumeAnchor.screen === masterWindow.screen) {\n            let minX = Math.max(0, volumeAnchor.minX);\n            let maxX = Math.min(scrW, volumeAnchor.maxX);\n            if (maxX - minX < result.w) { minX = 0; maxX = scrW; }\n            result.rx = Math.round(Math.max(minX, Math.min(maxX - result.w, volumeAnchor.centerX - result.w / 2)));\n        }\n\n'
command = 'Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle volume"])'
try:
    paths = [base / 'singletons/widgetcontrols/OsdController.qml', base / 'bar/faces/vol/VolFace.qml', base / 'Main.qml']
    originals = [p.read_text() for p in paths]
    controller, vol, main = originals
    anchor = '    property var volumePanelAnchor: null // local volume panel position\n'
    if anchor not in controller:
        needle = '    property bool isHovered: false\n'
        if controller.count(needle) != 1: raise ValueError('OSD controller changed')
        controller = controller.replace(needle, needle + anchor, 1)
    if helper not in vol:
        needle = '    property int configRevision: 0\n'
        if vol.count(needle) != 1 or vol.count(command) != 3: raise ValueError('volume button changed')
        vol = vol.replace(command, 'root.openVolumePanel()').replace(needle, helper + needle, 1)
    if block not in main:
        needle = '        if (!result) return null;\n\n        let scale = masterWindow.globalUiScale || 1.0;'
        if main.count(needle) != 1: raise ValueError('panel layout changed')
        main = main.replace(needle, '        if (!result) return null;\n\n' + block + '        let scale = masterWindow.globalUiScale || 1.0;', 1)
    updated = [controller, vol, main]
    for path, old, new in zip(paths, originals, updated):
        if old != new: path.write_text(new)
    sys.exit(10 if originals != updated else 0)
except (OSError, ValueError) as exc:
    print(f'Serpantinum volume alignment: {exc}', file=sys.stderr)
    sys.exit(1)
