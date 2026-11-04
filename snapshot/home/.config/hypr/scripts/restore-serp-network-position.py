#!/usr/bin/env python3
"""Restore network-panel alignment with Wi-Fi and Bluetooth buttons."""
from pathlib import Path
import sys

base = Path.home() / '.local/share/serpantinum/src/quickshell'
helper = '''    function openNetworkPanel() {
        if (root.isPreview) return;
        if (root.barWindow && !root.isVertical) {
            let point = root.mapToItem(null, 0, 0);
            OsdController.networkPanelAnchor = {
                screen: root.barWindow.screen,
                centerX: point.x + root.width / 2,
                minX: root.barWindow.currentBarMinX,
                maxX: root.barWindow.currentBarMaxX
            };
        } else {
            OsdController.networkPanelAnchor = null;
        }
        Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle network MODE"]);
    }

'''
block = '''        // Align the network panel with the Wi-Fi or Bluetooth bar button.
        let networkAnchor = OsdController.networkPanelAnchor;
        if (name === "network" && (bp === "top" || bp === "bottom") && networkAnchor
                && networkAnchor.screen === masterWindow.screen) {
            let minX = Math.max(0, networkAnchor.minX);
            let maxX = Math.min(scrW, networkAnchor.maxX);
            if (maxX - minX < result.w) { minX = 0; maxX = scrW; }
            result.rx = Math.round(Math.max(minX, Math.min(maxX - result.w, networkAnchor.centerX - result.w / 2)));
        }

'''
try:
    paths = [base / 'singletons/widgetcontrols/OsdController.qml', base / 'bar/faces/wifi/WifiFace.qml', base / 'bar/faces/bt/BtFace.qml', base / 'Main.qml']
    original = [p.read_text() for p in paths]
    controller, wifi, bt, main = original
    anchor = '    property var networkPanelAnchor: null // local network panel position\n'
    if anchor not in controller:
        needle = '    property var volumePanelAnchor: null // local volume panel position\n'
        if controller.count(needle) != 1: raise ValueError('OSD controller changed')
        controller = controller.replace(needle, needle + anchor, 1)
    def update_face(source, mode):
        desired = helper.replace('MODE', mode)
        if desired in source: return source
        command = 'Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle network ' + mode + '"])'
        needle = '    property int configRevision: 0\n'
        if source.count(command) != 3 or source.count(needle) != 1: raise ValueError(f'{mode} button changed')
        return source.replace(command, 'root.openNetworkPanel()').replace(needle, desired + needle, 1)
    wifi = update_face(wifi, 'wifi')
    bt = update_face(bt, 'bt')
    if block not in main:
        needle = '        let scale = masterWindow.globalUiScale || 1.0;'
        if main.count(needle) != 1: raise ValueError('panel layout changed')
        main = main.replace(needle, block + needle, 1)
    updated = [controller, wifi, bt, main]
    for path, old, new in zip(paths, original, updated):
        if old != new: path.write_text(new)
    sys.exit(10 if original != updated else 0)
except (OSError, ValueError) as exc:
    print(f'Serpantinum network alignment: {exc}', file=sys.stderr)
    sys.exit(1)
