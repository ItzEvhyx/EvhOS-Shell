import QtQuick
import "../"

Item {
    id: host
    signal navigate(string tab)
    signal arrange
    readonly property bool presented: DesktopPresets.hasDialog || DesktopPresets.editing
    visible: presented || card.opacity > 0.001

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: host.presented ? 0.46 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: if (DesktopPresets.hasDialog)
                DesktopPresets.dismissDialog()
            onWheel: event => event.accepted = true
        }
    }
    // This card floats over the page; opening it never changes page geometry.
    DesktopPresetSessionBar {
        id: card
        objectName: "presetDialogCard"
        width: Math.max(1, Math.min(Math.round(Scaler.s(680)), host.width - Math.round(Scaler.s(48))))
        maxContentHeight: Math.max(1, host.height - Math.round(Scaler.s(48)))
        x: Math.round((host.width - width) / 2)
        y: Math.round((host.height - height) / 2)
        height: implicitHeight
        onNavigate: tab => host.navigate(tab)
        onArrange: host.arrange()
    }
}
