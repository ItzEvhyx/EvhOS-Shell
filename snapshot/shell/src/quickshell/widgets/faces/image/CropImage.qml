import QtQuick
import "../../../reusables"

Item {
    id: root
    clip: true
    property alias source: image.source
    property alias fillMode: image.fillMode
    property alias asynchronous: image.asynchronous
    property alias cache: image.cache
    property alias smooth: image.smooth
    property alias antialiasing: image.antialiasing
    property alias allowAnimation: image.allowAnimation
    property alias playing: image.playing
    readonly property alias status: image.status
    readonly property real paintedWidth: cropActive ? width : image.paintedWidth
    readonly property real paintedHeight: cropActive ? height : image.paintedHeight
    property bool cropActive: false
    property real cropZoom: 1
    property real cropX: 0
    property real cropY: 0
    readonly property real aspect: image.image && image.image.sourceSize.width > 0 && image.image.sourceSize.height > 0
        ? image.image.sourceSize.width / image.image.sourceSize.height : 1
    readonly property real coverWidth: Math.max(width, height * aspect) * Math.max(1, cropZoom)
    readonly property real coverHeight: Math.max(height, width / aspect) * Math.max(1, cropZoom)
    readonly property real panRangeX: Math.max(0, (coverWidth - width) / 2)
    readonly property real panRangeY: Math.max(0, (coverHeight - height) / 2)

    BoundedImage {
        id: image
        x: root.cropActive ? -root.panRangeX + Math.max(-1, Math.min(1, root.cropX)) * root.panRangeX : 0
        y: root.cropActive ? -root.panRangeY + Math.max(-1, Math.min(1, root.cropY)) * root.panRangeY : 0
        width: root.cropActive ? root.coverWidth : root.width
        height: root.cropActive ? root.coverHeight : root.height
    }
}
