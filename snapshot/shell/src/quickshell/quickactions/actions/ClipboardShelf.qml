import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../"
import "../../reusables"

Item {
    id: root
    property int requestedLayoutTemplate: 1
    property string safeActiveEdge: typeof activeEdge !== "undefined" ? activeEdge : "left"
    property bool horizontalEdge: safeActiveEdge === "top" || safeActiveEdge === "bottom"
    property real preferredWidth: horizontalEdge ? s(430) : s(460)
    property real preferredExtraLength: horizontalEdge ? s(460) : s(380)
    property real counterRotation: safeActiveEdge === "right" ? 180 : (safeActiveEdge === "bottom" ? 90 : (safeActiveEdge === "top" ? -90 : 0))
    property bool hasInputFocus: search.activeFocus
    property var interceptedShortcuts: hasInputFocus ? ["Left", "Right", "Up", "Down", "Return", "Enter"] : []
    property var entries: []
    property string errorText: ""
    function s(v) { return typeof scaleFunc === "function" ? scaleFunc(v) : v }
    function unfocusInputs() { search.focus = false }
    function refresh() { if (!reader.running && !action.running) reader.running = true }
    function perform(args) { if (action.running) return; action.command = ["python3", Caching.serpantinumDir + "/scripts/clipboard_shelf.py"].concat(args); action.running = true }
    property var filtered: entries
    onVisibleChanged: if (visible) refresh()
    Timer { interval: 3000; repeat: true; running: root.visible && search.text === ""; onTriggered: root.refresh() }
    Timer { id: searchDebounce; interval: 300; onTriggered: root.refresh() }
    Process {
        id: reader
        property string requestedQuery: ""
        command: ["python3", Caching.serpantinumDir + "/scripts/clipboard_shelf.py", "list", search.text]
        onStarted: requestedQuery = search.text
        onExited: if (requestedQuery !== search.text) searchDebounce.restart()
        stdout: StdioCollector { onStreamFinished: { try { let x = JSON.parse(text); if (Array.isArray(x)) { root.entries = x; root.errorText = "" } else root.errorText = x.error || "Could not load clipboard" } catch(e) { root.errorText = "Could not load clipboard" } } }
    }
    Process {
        id: action
        stdout: StdioCollector { onStreamFinished: { try { let x = JSON.parse(text); if (x.error) root.errorText = x.error } catch(e) {} } }
        onExited: (exitCode, exitStatus) => { if (exitCode !== 0 && root.errorText === "") root.errorText = "Clipboard action failed"; reader.running = true }
    }
    Item {
        anchors.centerIn: parent
        width: root.horizontalEdge ? parent.height : parent.width
        height: root.horizontalEdge ? parent.width : parent.height
        rotation: root.counterRotation
        clip: true
    ColumnLayout {
        anchors.fill: parent; anchors.margins: root.s(16); spacing: root.s(10)
        RowLayout {
            Layout.fillWidth: true
            Text { text: "Clipboard"; color: ThemeBackend.text; font.family: ThemeBackend.fontFamily; font.weight: Font.DemiBold; font.pixelSize: root.s(18); Layout.fillWidth: true }
            Text { text: "Local history"; color: ThemeBackend.subtext0; font.family: ThemeBackend.fontFamily; font.pixelSize: root.s(10) }
        }
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: root.s(36); radius: root.s(11)
            color: Qt.alpha(ThemeBackend.text, 0.08)
            TextInput {
                id: search; onTextChanged: searchDebounce.restart(); anchors.fill: parent; anchors.leftMargin: root.s(12); anchors.rightMargin: root.s(12)
                verticalAlignment: TextInput.AlignVCenter; color: ThemeBackend.text; selectionColor: ThemeBackend.blue
                font.family: ThemeBackend.fontFamily; font.pixelSize: root.s(12); clip: true
                Text { anchors.verticalCenter: parent.verticalCenter; visible: !search.text && !search.activeFocus; text: "Search text or images"; color: ThemeBackend.subtext0; font: search.font }
            }
        }
        Text { Layout.fillWidth: true; visible: root.errorText !== ""; text: root.errorText; elide: Text.ElideRight; color: ThemeBackend.red; font.pixelSize: root.s(10) }
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            Text { anchors.centerIn: parent; visible: list.count === 0; text: search.text ? "No matching clips" : "Your copied items appear here"; color: ThemeBackend.subtext0; font.family: ThemeBackend.fontFamily; font.pixelSize: root.s(12) }
            ListView {
                id: list; anchors.fill: parent; clip: true; spacing: root.s(7); model: root.filtered
                boundsBehavior: Flickable.StopAtBounds
                delegate: Rectangle {
                    id: card
                    required property var modelData
                    width: list.width; height: modelData.image ? root.s(82) : root.s(60); radius: root.s(12)
                    scale: click.pressed ? 0.97 : 1.0
                    Behavior on scale { NumberAnimation { duration: click.pressed ? 90 : 220; easing.type: Easing.OutCubic } }
                    color: click.pressed ? Qt.alpha(ThemeBackend.text, 0.17) : click.containsMouse ? Qt.alpha(ThemeBackend.text, 0.12) : Qt.alpha(ThemeBackend.text, 0.06)
                    MouseArea { id: click; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { let x = card.modelData; root.perform(["copy", x.pinned ? "pin" : "clip", x.pinned ? x.hash : x.id]) } }
                    RowLayout {
                        anchors.fill: parent; anchors.margins: root.s(8); spacing: root.s(10)
                        Rectangle {
                            Layout.preferredWidth: root.s(62); Layout.fillHeight: true; radius: root.s(8); color: Qt.alpha(ThemeBackend.text, 0.07); clip: true; visible: card.modelData.image
                            Image { anchors.fill: parent; source: card.modelData.thumbnail || ""; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                            Text { anchors.centerIn: parent; visible: !card.modelData.thumbnail; text: "󰋩"; font.family: ThemeBackend.iconFont; font.pixelSize: root.s(21); color: ThemeBackend.subtext0 }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: root.s(3)
                            Text { Layout.fillWidth: true; text: card.modelData.label || ""; color: ThemeBackend.text; font.family: ThemeBackend.fontFamily; font.pixelSize: root.s(12); elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.Wrap }
                            Text { text: card.modelData.pinned ? "Pinned" : (card.modelData.image ? "Image" : "Text"); color: ThemeBackend.subtext0; font.family: ThemeBackend.fontFamily; font.pixelSize: root.s(10) }
                        }
                        IconButton {
                            size: root.s(30); cornerRadius: root.s(9); buttonIcon: card.modelData.pinned ? "󰐃" : "󰐄"; iconFontSize: root.s(15)
                            accentColor: ThemeBackend.surface1; textColor: card.modelData.pinned ? ThemeBackend.text : ThemeBackend.subtext0
                            onClicked: root.perform(card.modelData.pinned ? ["unpin", card.modelData.hash] : ["pin", card.modelData.id])
                        }
                    }
                }
            }
        }
    }
    }
}
