#!/usr/bin/env python3
"""Restore media-panel alignment with the bar media control."""
from pathlib import Path
import sys

base = Path.home() / '.local/share/serpantinum/src/quickshell'
helper = '''    function openMediaPanel() {
        if (root.isPreview) return;
        if (root.barWindow && !root.isVertical) {
            let point = root.mapToItem(null, 0, 0);
            OsdController.mediaPanelAnchor = {
                screen: root.barWindow.screen,
                centerX: point.x + root.width / 2,
                minX: root.barWindow.currentBarMinX,
                maxX: root.barWindow.currentBarMaxX
            };
        } else {
            OsdController.mediaPanelAnchor = null;
        }
        Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle music"]);
    }

'''
block = '''        // Align the music panel with the bar media control.
        let mediaAnchor = OsdController.mediaPanelAnchor;
        if (name === "music" && (bp === "top" || bp === "bottom") && mediaAnchor
                && mediaAnchor.screen === masterWindow.screen) {
            let minX = Math.max(0, mediaAnchor.minX);
            let maxX = Math.min(scrW, mediaAnchor.maxX);
            if (maxX - minX < result.w) { minX = 0; maxX = scrW; }
            result.rx = Math.round(Math.max(minX, Math.min(maxX - result.w, mediaAnchor.centerX - result.w / 2)));
        }

'''
try:
    paths = [base / 'singletons/widgetcontrols/OsdController.qml', base / 'bar/faces/media/MediaFace.qml', base / 'Main.qml']
    original = [p.read_text() for p in paths]
    controller, media, main = original
    anchor = '    property var mediaPanelAnchor: null // local media panel position\n'
    if anchor not in controller:
        needle = '    property var networkPanelAnchor: null // local network panel position\n'
        if controller.count(needle) != 1: raise ValueError('OSD controller changed')
        controller = controller.replace(needle, needle + anchor, 1)
    if helper not in media:
        command = 'onClicked: Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle music"])'
        needle = '    property int configRevision: 0\n'
        if media.count(command) != 1 or media.count(needle) != 1: raise ValueError('media button changed')
        media = media.replace(command, 'onClicked: root.openMediaPanel()', 1).replace(needle, helper + needle, 1)
    if block not in main:
        needle = '        let scale = masterWindow.globalUiScale || 1.0;'
        if main.count(needle) != 1: raise ValueError('panel layout changed')
        main = main.replace(needle, block + needle, 1)
    updated = [controller, media, main]
    for path, old, new in zip(paths, original, updated):
        if old != new: path.write_text(new)
    sys.exit(10 if original != updated else 0)
except (OSError, ValueError) as exc:
    print(f'Serpantinum media alignment: {exc}', file=sys.stderr)
    sys.exit(1)
