import QtQuick
import QtQuick.Layouts
import "../../"
import "../"

Rectangle {
    id: root
    Layout.fillWidth: true

    readonly property bool isSettingsBlob: true

    property real cornerRadius: root.s(16)
    property color baseColor: Qt.alpha(ThemeBackend.text, 0.045)

    function s(v) { return (typeof Scaler !== "undefined") ? Scaler.s(v) : v }

    default property alias content: blobCol.data

    radius: root.cornerRadius
    color: blobGlass.active ? "transparent" : root.baseColor
    border.width: 1
    border.color: Qt.alpha(ThemeBackend.text, 0.08)
    clip: true

    implicitHeight: blobCol.implicitHeight
    Layout.preferredHeight: implicitHeight

    GlassFill {
        id: blobGlass
        anchors.fill: parent
        radius: root.cornerRadius
        tintColor: ThemeBackend.surface0
        tintAmount: 0.26
    }

    ColumnLayout {
        id: blobCol
        readonly property bool isBlobColumn: true
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 0
    }
}
