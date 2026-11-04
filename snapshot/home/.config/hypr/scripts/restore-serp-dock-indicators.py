#!/usr/bin/env python3
"""Keep the minimal running-app indicators after shell updates."""
from pathlib import Path
import sys

base = Path.home() / '.local/share/serpantinum/src/quickshell/dock'

def indicator(root):
    return '''            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            z: 2

            // A short line marks every running app; the focused app is brighter.
            Rectangle {
                width: dockWindow.isVertical ? dockWindow.s(3) : dockWindow.s(ROOT.isAppFocused ? 18 : 12)
                height: dockWindow.isVertical ? dockWindow.s(ROOT.isAppFocused ? 18 : 12) : dockWindow.s(3)
                radius: dockWindow.s(2)
                anchors.horizontalCenter: dockWindow.isVertical ? undefined : parent.horizontalCenter
                anchors.verticalCenter: dockWindow.isVertical ? parent.verticalCenter : undefined
                anchors.bottom: !dockWindow.isVertical && dockWindow.dockPosition !== "top" ? parent.bottom : undefined
                anchors.top: !dockWindow.isVertical && dockWindow.dockPosition === "top" ? parent.top : undefined
                anchors.left: dockWindow.isVertical && dockWindow.dockPosition === "right" ? parent.left : undefined
                anchors.right: dockWindow.isVertical && dockWindow.dockPosition === "left" ? parent.right : undefined
                anchors.margins: dockWindow.s(1)
                color: Qt.alpha(ThemeBackend.text, ROOT.isOnlyElsewhere ? 0.4 : (ROOT.isAppFocused ? 1.0 : 0.7))
                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 160 } }
            }
'''.replace('ROOT', root)

try:
    changed = False
    for name, root, marker in [('DockAppButton.qml', 'dockButton', 'id: indicatorContainer'), ('DockRunningButton.qml', 'runningDockButton', 'id: runningIndicatorContainer')]:
        path = base / name
        source = path.read_text()
        new = indicator(root)
        if new in source: continue
        pos = source.index(marker)
        start = source.index('            anchors.', pos)
        end = source.index('\n        }\n\n        MouseArea {', start)
        if 'isOnlyElsewhere' not in source[start:end]: raise ValueError(f'{name} indicator layout changed')
        path.write_text(source[:start] + new + source[end:])
        changed = True
    sys.exit(10 if changed else 0)
except (OSError, ValueError) as exc:
    print(f'Serpantinum dock indicators: {exc}', file=sys.stderr)
    sys.exit(1)
