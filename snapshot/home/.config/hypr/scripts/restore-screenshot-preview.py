#!/usr/bin/env python3
"""Restore the local screenshot notification thumbnail after shell updates.

Exit 10 when changed, 0 when already installed, and 1 if the upstream
component changed in a way that needs manual review.
"""
import os
from pathlib import Path
import re
import sys
import tempfile

path = Path.home() / '.local/share/serpantinum/src/quickshell/notifications/types/Screenshot.qml'
marker = 'id: localScreenshotPreview'
try:
    source = path.read_text()
    pattern = re.compile(r'    iconArea: \[.*?\n    \]\n\n    headerArea:', re.S)
    if len(pattern.findall(source)) != 1 or 'function getImagePath()' not in source:
        raise ValueError('notification layout changed; preview needs manual review')
    replacement = '''    iconArea: [
        Item {
            id: localScreenshotPreview
            anchors.centerIn: parent
            width: s(34)
            height: s(34)

            Rectangle {
                id: localPreviewMask
                anchors.fill: parent
                radius: width / 2
                color: "black"
                layer.enabled: true
                visible: false
            }
            Image {
                id: localPreviewImage
                anchors.fill: parent
                source: {
                    let p = faceRoot.getImagePath();
                    if (!p) return "";
                    if (p.startsWith("file://") || p.startsWith("image://")) return p;
                    if (p.startsWith("/")) return "file://" + p;
                    return "";
                }
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
            }
            MultiEffect {
                anchors.fill: parent
                source: localPreviewImage
                maskEnabled: true
                maskSource: localPreviewMask
                visible: localPreviewImage.status === Image.Ready
            }
            Text {
                anchors.centerIn: parent
                visible: localPreviewImage.status !== Image.Ready
                text: "󰄀"
                font.family: ThemeBackend.iconFont
                font.pixelSize: s(24)
                color: faceRoot.accentColor
            }
        }
    ]

    headerArea:'''
    updated = source if marker in source else pattern.sub(lambda _: replacement, source, count=1)
    if 'id: localLargeScreenshotPreview' not in updated:
        anchor = '    overrideClick: true\n'
        if updated.count(anchor) != 1 or not updated.rstrip().endswith('}'):
            raise ValueError('notification layout changed; large preview needs manual review')
        updated = updated.replace(anchor, anchor + '    expanded: !isPopup\n', 1)
        large = '''
    Image {
        id: localLargeScreenshotPreview
        Layout.fillWidth: true
        Layout.maximumWidth: s(260)
        Layout.preferredHeight: s(150)
        Layout.topMargin: s(6)
        visible: !faceRoot.isPopup && source.toString() !== ""
        source: {
            let p = faceRoot.getImagePath();
            if (!p) return "";
            if (p.startsWith("file://") || p.startsWith("image://")) return p;
            if (p.startsWith("/")) return "file://" + p;
            return "";
        }
        fillMode: Image.PreserveAspectFit
        asynchronous: true
    }
'''
        updated = updated.rstrip()[:-1] + large + '}\n'
    if updated == source:
        sys.exit(0)
    fd, temp = tempfile.mkstemp(prefix='.Screenshot.', suffix='.qml', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as f:
            f.write(updated)
        os.chmod(temp, path.stat().st_mode & 0o777)
        os.replace(temp, path)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)
    sys.exit(10)
except (OSError, ValueError) as exc:
    print(f'Screenshot preview: {exc}', file=sys.stderr)
    sys.exit(1)
