import QtQuick
import QtQuick.Controls
import "../"

Button {
    id: button
    property bool primary: false
    property bool destructive: false
    hoverEnabled: true
    font.family: "sans-serif"
    font.pixelSize: Math.round(Scaler.s(13))
    font.weight: Font.DemiBold
    padding: Math.round(Scaler.s(9))
    leftPadding: Math.round(Scaler.s(12))
    rightPadding: leftPadding
    implicitHeight: Math.round(Scaler.s(38))
    opacity: enabled ? 1 : 0.42
    scale: down ? 0.97 : 1
    Behavior on opacity {
        NumberAnimation {
            duration: 140
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: 130
            easing.type: Easing.OutCubic
        }
    }
    contentItem: Text {
        text: button.text
        font: button.font
        color: button.destructive ? ThemeBackend.red : (button.primary ? ThemeBackend.crust : ThemeBackend.text)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        radius: Math.round(Scaler.s(9))
        color: button.primary ? (button.hovered ? Qt.lighter(ThemeBackend.mauve, 1.08) : ThemeBackend.mauve) : (button.destructive ? Qt.alpha(ThemeBackend.red, button.hovered ? 0.17 : 0.07) : Qt.alpha(ThemeBackend.text, button.down ? 0.16 : button.hovered ? 0.105 : 0.055))
        border.width: button.activeFocus ? 2 : 1
        border.color: button.activeFocus ? ThemeBackend.mauve : Qt.alpha(button.destructive ? ThemeBackend.red : ThemeBackend.text, button.hovered ? 0.3 : 0.14)
        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: 150
            }
        }
    }
}
