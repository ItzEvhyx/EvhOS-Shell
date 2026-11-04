import QtQuick
import QtQuick.Controls
import "."
Button {
    id: action
    property color textColor: ThemeBackend.text
    implicitHeight: 30
    implicitWidth: actionText.implicitWidth + 20
    padding: 0
    background: Rectangle {
        radius: 7
        color: action.down ? Qt.alpha(ThemeBackend.text, 0.18) : (action.hovered ? Qt.alpha(ThemeBackend.text, 0.10) : "transparent")
    }
    contentItem: Text {
        id: actionText
        text: action.text
        font.pixelSize: 12
        color: action.enabled ? action.textColor : ThemeBackend.subtext0
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        opacity: action.enabled ? 1 : 0.45
    }
}
