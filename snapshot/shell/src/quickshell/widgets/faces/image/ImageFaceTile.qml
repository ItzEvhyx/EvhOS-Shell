import "."
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../../reusables"
import "../../../"

Item {
    id: root
    anchors.fill: parent

    property real minWidth: 30
    property real minHeight: 30
    property real maxWidth: 4000
    property real maxHeight: 4000
    property real minAspect: 0.02
    property real maxAspect: 50.0
    property bool isRound: false

    property bool cropActive: false
    property real cropZoom: 1
    property real cropX: 0
    property real cropY: 0
    readonly property real cropPanRangeX: srcImage.panRangeX
    readonly property real cropPanRangeY: srcImage.panRangeY

    property string imagePath: (typeof model !== "undefined" && model && model.wImagePath) ? model.wImagePath : (parent && parent.wImagePath ? parent.wImagePath : "")

    Rectangle {
        id: bgRect
        anchors.fill: parent
        color: (root.imagePath === "" || srcImage.status !== Image.Ready) ? ThemeBackend.surface0 : "transparent"
        radius: Math.min(18, width / 2, height / 2)
        antialiasing: true

        CropImage {
            id: srcImage
            cropActive: root.cropActive
            cropZoom: root.cropZoom
            cropX: root.cropX
            cropY: root.cropY
            anchors.fill: parent
            source: root.imagePath !== "" ? (root.imagePath.startsWith("file://") ? root.imagePath : "file://" + root.imagePath) : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            antialiasing: true
            allowAnimation: true
            playing: true
            visible: false
        }

        Item {
            id: maskContainer
            anchors.fill: parent
            visible: false
            layer.enabled: true
            layer.smooth: true

            Rectangle {
                anchors.fill: parent
                radius: Math.min(18, width / 2, height / 2)
                color: "white"
                antialiasing: true
            }
        }

        MultiEffect {
            id: effect
            anchors.fill: parent
            source: srcImage
            autoPaddingEnabled: false
            maskEnabled: true
            maskSource: maskContainer
            visible: root.imagePath !== "" && srcImage.status === Image.Ready
        }

        Item {
            anchors.fill: parent
            visible: root.imagePath === "" || srcImage.status !== Image.Ready

            Text {
                anchors.centerIn: parent
                text: "󰋩"
                font.family: ThemeBackend.iconFont
                font.pixelSize: Math.max(16, Math.min(root.width, root.height) * 0.35)
                color: ThemeBackend.subtext0
            }
        }
    }
}
