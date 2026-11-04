#!/usr/bin/env python3
"""Restore independent, translucent dock and top-bar backgrounds."""
import os
from pathlib import Path
import sys
import tempfile

base = Path.home() / '.local/share/serpantinum/src/quickshell'
changes = {
    **{
        base / popup: [
            ('color: Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)',
             'color: Qt.alpha(ThemeBackend.base, 0.78) // local translucent widget')
        ]
        for popup in ('calendar/CalendarPopup.qml', 'network/NetworkPopup.qml',
                      'volume/VolumePopup.qml', 'media/MusicPopup.qml',
                      'syspanel/SystemPanel.qml', 'guide/GuidePopup.qml')
    },
    base / 'popouts/Osd.qml': [
        ('Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)',
         'Qt.alpha(ThemeBackend.base, 0.78) /* local translucent OSD */'),
    ],
    base / 'launcher/Launcher.qml': [
        ('Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)',
         'Qt.alpha(ThemeBackend.base, 0.78) /* local translucent launcher */'),
    ],
    base / 'notifications/Notification.qml': [
        ('    property bool expanded: false',
         '    property bool expanded: !!(delegateWrapper && delegateWrapper.actionArray && delegateWrapper.actionArray.some(a => a.id === "battery-dismiss")) // show battery alarm dismiss button'),
        ('            Sounds.play(soundFile);',
         '            Sounds.play(soundFile, 1.0, 0, true); // notification sound independent of UI SFX mute'),
    ],
    base / 'dock/DockContainer.qml': [
        ('            id: dockBg\n',
         '            id: dockBg\n            border.width: dockWindow.dockBackground ? 1 : 0 // local contrast outline\n            border.color: Qt.alpha(ThemeBackend.text, 0.42)\n'),
    ],
    base / 'bar/Bar.qml': [
        ('            id: barWindowRoot\n', '            id: barWindowRoot\n            WlrLayershell.namespace: "qs-custom-bar" // local glass style\n'),
        ('            property real barOpacity: ThemeBackend.elementOpacity', '            property real barOpacity: 0.78 // local glass style'),
    ],
    base / 'bar/faces/media/MediaFace.qml': [
        ('bgOpacity: ThemeBackend.liquidGlass ? 1.0 : root.barOpacity', 'bgOpacity: 0 // local icon-only media controls'),
        ('color: mediaThumbGlass.active ? "transparent" : (root.isCompact ? Qt.lighter(ThemeBackend.surface1, 1.1) : ThemeBackend.surface1)', 'color: "transparent" // local icon-only horizontal media artwork'),
        ('id: mediaThumbGlass\n', 'id: mediaThumbGlass\n                                    visible: false // local icon-only media artwork\n'),
        ('color: sideThumbGlass.active ? "transparent" : (root.isCompact ? Qt.lighter(ThemeBackend.surface1, 1.1) : ThemeBackend.surface1)', 'color: "transparent" // local icon-only vertical media artwork'),
        ('id: sideThumbGlass\n', 'id: sideThumbGlass\n                        visible: false // local icon-only media artwork\n'),
    ],
    base / 'dock/DockWindow.qml': [
        ('    readonly property real dockOpacity: dockBackground ? ThemeBackend.elementOpacity : 0.0', '    readonly property real dockOpacity: dockBackground ? 0.56 : 0.0 // local glass style'),
    ],
    base / 'dock/DockAppButton.qml': [
        ('            color: dockBtnGlass.active ? "transparent" : Qt.alpha(btnMa.pressed ? Qt.darker(dockButton.btnColor, 1.12) : (btnMa.containsMouse ? Qt.lighter(dockButton.btnColor, 1.12) : dockButton.btnColor), ThemeBackend.elementOpacity)',
         '            color: "transparent" // local icon-only dock'),
        ('                id: dockBtnGlass\n', '                id: dockBtnGlass\n                visible: false // local icon-only dock\n'),
    ],
    base / 'dock/DockRunningButton.qml': [
        ('            color: runningBtnGlass.active ? "transparent" : Qt.alpha(runningBtnMa.pressed ? Qt.darker(runningDockButton.btnColor, 1.12) : (runningBtnMa.containsMouse ? Qt.lighter(runningDockButton.btnColor, 1.12) : runningDockButton.btnColor), ThemeBackend.elementOpacity)',
         '            color: "transparent" // local icon-only dock'),
        ('                id: runningBtnGlass\n', '                id: runningBtnGlass\n                visible: false // local icon-only dock\n'),
    ],
}
try:
    pending = []
    for path, edits in changes.items():
        source = path.read_text()
        updated = source
        if path.name == 'DockWindow.qml':
            updated = updated.replace('    readonly property real dockOpacity: dockBackground ? 0.78 : 0.0 // local glass style', '    readonly property real dockOpacity: dockBackground ? 0.56 : 0.0 // local glass style')
        for before, after in edits:
            # The redesigned system panel uses its own translucent surface.
            if path.name == 'SystemPanel.qml' and before.startswith('color: Qt.alpha(ThemeBackend.base,') and 'color: Qt.alpha(ThemeBackend.base, 0.84)' in updated:
                continue
            if path.name == 'Osd.qml' and 'Qt.alpha(ThemeBackend.base, 0.68) /* local translucent OSD */' in updated:
                continue
            if after in updated: continue
            if path.name in ('Osd.qml', 'Launcher.qml') and updated.count(before) == 3:
                updated = updated.replace(before, after)
                continue
            if path.name == 'MediaFace.qml' and updated.count(before) == 6:
                updated = updated.replace(before, after)
                continue
            if updated.count(before) != 1:
                raise ValueError(f'{path.name} layout changed; glass style needs manual review')
            updated = updated.replace(before, after, 1)
        if updated != source: pending.append((path, updated))
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
    print(f'Serpantinum glass style: {exc}', file=sys.stderr)
    sys.exit(1)
