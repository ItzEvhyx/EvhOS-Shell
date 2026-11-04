#!/usr/bin/env python3
"""Restore the compact Cava visualizer in the top-bar media preview."""
from pathlib import Path
import sys

path = Path.home() / '.local/share/serpantinum/src/quickshell/bar/faces/media/MediaFace.qml'
old = '''                                Text {
                                    text: root.infoMode === "author"
                                        ? (root.isPreview ? I18n.t("guide.bar.media.preview.author", "Song author") : (isMediaActive && player ? (player.trackArtist || "") : ""))
                                        : (root.isPreview ? "01:24 / 03:42" : (isMediaActive && player ? (root.formatTime(MprisController.livePosition) + " / " + root.formatTime(player.length)) : ""))
                                    font.family: ThemeBackend.fontFamily
                                    font.weight: Font.Black
                                    font.pixelSize: barWindow ? barWindow.cs(root.isCompact ? 9 : 10) : (root.isCompact ? 9 : 10)
                                    color: root.isCompact ? ThemeBackend.overlay2 : ThemeBackend.subtext0
                                    width: parent.width
                                    elide: Text.ElideRight
                                    visible: isMediaActive
                                }
'''
new = '''                                Visualizer {
                                    id: mediaPreviewVisualizer
                                    width: parent.width
                                    height: barWindow ? barWindow.cs(root.isCompact ? 9 : 10) : 10
                                    visible: root.isMediaActive
                                    active: root.isPreview || (root.isMediaActive && root.isPlaying && root.visible && (!barWindow || barWindow.visible))
                                    previewDemo: root.isPreview
                                    count: 18
                                    mirrored: false
                                    alignment: "end"
                                    spacing: 2
                                    minLength: 1
                                    color: ThemeBackend.mauve
                                    rise: 0.5
                                    fall: 0.35
                                    property bool subscribed: false
                                    function updateSubscription() {
                                        let want = active && !root.isPreview;
                                        if (want && !subscribed) { Cava.registerConsumer(); subscribed = true; }
                                        else if (!want && subscribed) { Cava.unregisterConsumer(); subscribed = false; }
                                    }
                                    onActiveChanged: updateSubscription()
                                    Component.onCompleted: updateSubscription()
                                    Component.onDestruction: if (subscribed) Cava.unregisterConsumer()
                                }
'''
try:
    source = path.read_text()
    updated = source
    marker = '                            id: infoLayout\n'
    direction = marker + '                            layoutDirection: Qt.RightToLeft // local media layout\n'
    if direction not in updated:
        if updated.count(marker) != 1: raise ValueError('media information layout changed')
        updated = updated.replace(marker, direction, 1)
    if new not in updated:
        if updated.count(old) != 1: raise ValueError('media detail layout changed')
        updated = updated.replace(old, new, 1)
    if updated != source:
        path.write_text(updated)
        sys.exit(10)
    sys.exit(0)
except (OSError, ValueError) as exc:
    print(f'Serpantinum media visualizer: {exc}', file=sys.stderr)
    sys.exit(1)
