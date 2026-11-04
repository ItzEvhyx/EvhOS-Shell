#!/usr/bin/env python3
"""Restore the animated hover highlight on the top notch."""
from pathlib import Path
import sys

base = Path.home() / '.local/share/serpantinum/src/quickshell/bar'
try:
    bar_path, top_path = base / 'Bar.qml', base / 'TopBar.qml'
    bar, top = bar_path.read_text(), top_path.read_text()
    original_bar, original_top = bar, top
    old = '            property real barOpacity: 0.78 // local glass style\n'
    new = old + '''            property real notchHoverStrength: (barStyle === "solid" && barPosition === "top" && (barHover.hovered || (TrayMenuController.isVisible && TrayMenuController.screen === barWindowRoot.screen))) ? 0.12 : 0
            Behavior on notchHoverStrength { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
'''
    if new not in bar:
        if bar.count(old) != 1: raise ValueError('bar opacity setting changed')
        bar = bar.replace(old, new, 1)
    old = '    property bool isTopNotch: isSolid && !isFill && !!barWindow && barWindow.barPosition === "top" // local notch\n'
    new = old + '    readonly property color notchBaseColor: isTopNotch && barWindow ? Qt.tint(ThemeBackend.base, Qt.alpha(ThemeBackend.text, barWindow.notchHoverStrength)) : ThemeBackend.base // local hover highlight\n'
    if new not in top:
        if top.count(old) != 1: raise ValueError('notch setting changed')
        top = top.replace(old, new, 1)
    old = 'Qt.alpha(ThemeBackend.base, (barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0)'
    new = 'Qt.alpha(contentWrapper.notchBaseColor, (barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0)'
    if top.count(new) != 6:
        if top.count(old) != 6: raise ValueError('bar background colors changed')
        top = top.replace(old, new)
    if bar != original_bar: bar_path.write_text(bar)
    if top != original_top: top_path.write_text(top)
    sys.exit(10 if bar != original_bar or top != original_top else 0)
except (OSError, ValueError) as exc:
    print(f'Serpantinum notch hover: {exc}', file=sys.stderr)
    sys.exit(1)
