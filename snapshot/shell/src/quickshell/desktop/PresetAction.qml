import QtQuick
import QtQuick.Controls
import "../"

Button {
    id: button
    property bool primary: false
    property bool destructive: false
    font.family: ThemeBackend.fontFamily
    font.pixelSize: Math.round(Scaler.s(12))
    padding: Math.round(Scaler.s(9))
    leftPadding: Math.round(Scaler.s(12))
    rightPadding: leftPadding
    implicitHeight: Math.round(Scaler.s(34))
    opacity: enabled ? 1 : 0.45
    contentItem: Text {
        text: button.text
        font: button.font
        color: button.destructive ? ThemeBackend.red : (button.primary ? ThemeBackend.crust : ThemeBackend.text)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        radius: Math.round(Scaler.s(7))
        color: button.primary ? ThemeBackend.mauve : (button.down ? ThemeBackend.surface2 : (button.hovered ? ThemeBackend.surface1 : ThemeBackend.surface0))
        border.width: button.activeFocus ? 2 : 1
        border.color: button.activeFocus ? ThemeBackend.mauve : Qt.alpha(ThemeBackend.text, 0.15)
    }
}
