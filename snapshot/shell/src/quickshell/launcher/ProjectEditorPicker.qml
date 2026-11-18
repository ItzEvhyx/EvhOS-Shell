import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../"
import "../reusables"

FocusScope {
    id: root
    property string projectPath: ""
    property var editors: []
    property bool loading: false
    property bool launching: false
    property string errorText: ""
    property int selectedIndex: 0
    signal chosen(string editorId)
    signal canceled()

    function s(value) { return Scaler.s(value); }
    function choose(index) {
        if (!loading && !launching && index >= 0 && index < editors.length)
            chosen(editors[index].id);
    }
    function moveSelection(direction) {
        if (editors.length) selectedIndex = (selectedIndex + direction + editors.length) % editors.length;
    }
    onVisibleChanged: {
        if (visible) {
            selectedIndex = 0;
            forceActiveFocus();
        }
    }
    onEditorsChanged: selectedIndex = 0
    onSelectedIndexChanged: editorList.positionViewAtIndex(selectedIndex, ListView.Contain)

    Keys.priority: Keys.BeforeItem
    Keys.onPressed: event => {
        event.accepted = true;
        if (event.key === Qt.Key_Escape) { if (!launching) canceled(); }
        else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) moveSelection(event.modifiers & Qt.ShiftModifier ? -1 : 1);
        else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) moveSelection(-1);
        else if (event.key === Qt.Key_Home) selectedIndex = 0;
        else if (event.key === Qt.Key_End) selectedIndex = Math.max(0, editors.length - 1);
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) choose(selectedIndex);
    }

    Rectangle { anchors.fill: parent; color: "#50000000" }
    MouseArea { anchors.fill: parent; onClicked: { if (!root.launching) root.canceled(); } }

    Rectangle {
        id: dialog
        anchors.centerIn: parent
        width: Math.min(root.s(540), parent.width - root.s(40))
        height: Math.min(content.implicitHeight + root.s(36), parent.height - root.s(64))
        radius: root.s(22)
        color: popupGlass.active ? "transparent" : Qt.alpha(ThemeBackend.base, 0.82)
        border.width: 1
        border.color: Qt.alpha(ThemeBackend.text, 0.16)
        clip: true
        readonly property Item glassBackdropItem: backdrop
        WallpaperBlur { id: backdrop; z: -1; anchors.fill: parent; radius: parent.radius }
        GlassFill { id: popupGlass; anchors.fill: parent; radius: parent.radius; tintColor: ThemeBackend.base; tintAmount: 0.40; shadow: 0 }
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: root.s(18)
            spacing: root.s(10)
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: "Open project in…"
                    color: ThemeBackend.text
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: root.s(19)
                    font.weight: Font.DemiBold
                }
                Rectangle {
                    width: root.s(28); height: width; radius: width / 2
                    color: Qt.alpha(ThemeBackend.text, closeMouse.containsMouse ? 0.14 : 0.06)
                    Text { anchors.centerIn: parent; text: "×"; font.pixelSize: root.s(20); color: ThemeBackend.subtext0 }
                    MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: !root.launching; onClicked: root.canceled() }
                }
            }
            Text {
                Layout.fillWidth: true
                text: root.projectPath.split("/").filter(part => part !== "").pop() || "Project"
                color: ThemeBackend.text
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.s(13)
                font.weight: Font.Medium
                elide: Text.ElideMiddle
            }
            Text {
                Layout.fillWidth: true
                text: root.projectPath
                color: ThemeBackend.subtext0
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.s(10)
                elide: Text.ElideMiddle
                maximumLineCount: 1
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.alpha(ThemeBackend.text, 0.10) }
            ListView {
                id: editorList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(6, root.editors.length) * root.s(58)
                Layout.maximumHeight: Math.max(root.s(58), root.height - root.s(210))
                clip: true
                spacing: root.s(5)
                boundsBehavior: Flickable.StopAtBounds
                model: root.editors
                delegate: Rectangle {
                    id: editorRow
                    required property var modelData
                    required property int index
                    objectName: "editor-row-" + index
                    width: editorList.width
                    height: root.s(53)
                    radius: root.s(12)
                    readonly property bool selected: index === root.selectedIndex
                    color: Qt.alpha(ThemeBackend.text, selected ? 0.90 : (rowMouse.containsMouse ? 0.08 : 0))
                    Behavior on color { ColorAnimation { duration: 120 } }
                    RowLayout {
                        anchors.fill: parent; anchors.margins: root.s(10); spacing: root.s(12)
                        Rectangle {
                            Layout.preferredWidth: root.s(32); Layout.preferredHeight: root.s(32)
                            radius: root.s(8); color: Qt.alpha(selected ? ThemeBackend.base : ThemeBackend.text, 0.10)
                            Image {
                                id: appIcon
                                anchors.fill: parent; anchors.margins: root.s(4)
                                source: IconPacks.resolveIcon(editorRow.modelData.icon || "", editorRow.modelData.id || "", 64)
                                smooth: !IconPacks.pixelated
                                mipmap: !IconPacks.pixelated
                                asynchronous: true
                                fillMode: Image.PreserveAspectFit
                            }
                            Text { anchors.centerIn: parent; visible: appIcon.status !== Image.Ready; text: editorRow.modelData.name.charAt(0); color: selected ? ThemeBackend.crust : ThemeBackend.text; font.pixelSize: root.s(18) }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: editorRow.modelData.name
                            color: selected ? ThemeBackend.crust : ThemeBackend.text
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(13)
                            font.weight: selected ? Font.DemiBold : Font.Normal
                            elide: Text.ElideRight
                        }
                        Text { text: "↵"; visible: selected; color: ThemeBackend.crust; font.pixelSize: root.s(18) }
                    }
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !root.launching
                        onPositionChanged: root.selectedIndex = editorRow.index
                        onClicked: { root.selectedIndex = editorRow.index; root.choose(editorRow.index); }
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                visible: root.loading || root.launching || root.editors.length === 0 || root.errorText !== ""
                text: root.errorText || (root.loading ? "Finding installed editors…" : root.launching ? "Opening project…" : "No installed editor was found.")
                color: ThemeBackend.subtext0
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.s(11)
                wrapMode: Text.Wrap
            }
            Text {
                Layout.fillWidth: true
                text: "↑ ↓  Choose an editor     Enter  Open     Esc  Back"
                color: Qt.alpha(ThemeBackend.subtext0, 0.80)
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.s(10)
            }
        }
    }
}
