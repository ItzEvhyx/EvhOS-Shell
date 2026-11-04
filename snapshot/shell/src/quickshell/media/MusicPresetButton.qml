import QtQuick
import QtQuick.Layouts
import "../"

Item {
    id: button
    required property var root
    property string name: ""
    readonly property bool isActivePreset: root.eqData && root.eqData.preset === name
    Layout.fillWidth: true
    Layout.preferredWidth: 1
    Layout.preferredHeight: root.s(30)
    implicitHeight: root.s(30)
    Rectangle {
        anchors.fill: parent
        radius: root.s(10)
        color: button.isActivePreset ? Qt.alpha(ThemeBackend.text, 0.17) : (mouse.containsMouse ? Qt.alpha(ThemeBackend.text, 0.10) : Qt.alpha(ThemeBackend.text, 0.045))
        border.width: 1
        border.color: Qt.alpha(ThemeBackend.text, button.isActivePreset ? 0.30 : 0.08)
        scale: mouse.pressed ? 0.96 : 1.0
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 150 } }
    }
    Text {
        anchors.centerIn: parent
        text: I18n.t("music.presets." + button.name.toLowerCase())
        font.family: ThemeBackend.fontFamily
        font.pixelSize: root.s(11.5)
        font.weight: button.isActivePreset ? Font.DemiBold : Font.Normal
        color: button.isActivePreset || mouse.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.applyPresetOptimistically(button.name)
    }
}
