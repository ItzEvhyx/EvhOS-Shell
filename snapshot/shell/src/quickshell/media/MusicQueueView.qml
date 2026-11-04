import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "../reusables"

Item {
    id: queueView
    required property var root
    anchors.fill: parent
    visible: root.bottomSectionSwitch.currentIndex === 3
    property var tracks: []
    property bool available: false
    property bool currentKnown: false
    property bool loaded: false
    property string currentBus: root.targetPlayer ? (root.targetPlayer.dbusName || "") : ""
    function refresh() {
        if (!visible || !root.active || reader.running) return;
        if (!currentBus) { tracks = []; available = false; loaded = true; return }
        reader.busName = currentBus; reader.command = ["python3", Caching.serpantinumDir + "/scripts/media_queue.py", currentBus]; reader.running = true;
    }
    onVisibleChanged: if (visible) { loaded = false; refresh() }
    onCurrentBusChanged: { tracks = []; loaded = false; refresh() }
    Timer { interval: 5000; repeat: true; running: queueView.visible && root.active; onTriggered: queueView.refresh() }
    Process {
        id: reader
        property string busName: ""
        stdout: StdioCollector { onStreamFinished: {
            if (reader.busName !== queueView.currentBus) { queueView.refresh(); return }
            try { let x = JSON.parse(text); queueView.available = !!x.available; queueView.currentKnown = !!x.currentKnown; queueView.tracks = x.tracks || []; queueView.loaded = true }
            catch(e) { queueView.available = false; queueView.tracks = []; queueView.loaded = true }
        } }
        onExited: { if (busName !== queueView.currentBus) queueView.refresh() }
    }
    Process { id: goTo; onExited: refreshDelay.restart() }
    Timer { id: refreshDelay; interval: 500; onTriggered: queueView.refresh() }
    Rectangle {
        anchors.fill: parent; anchors.topMargin: root.s(8); radius: root.s(15)
        color: Qt.alpha(ThemeBackend.text, 0.035); border.width: 1; border.color: Qt.alpha(ThemeBackend.text, 0.07)
        ColumnLayout {
            anchors.fill: parent; anchors.margins: root.s(12); spacing: root.s(6)
            RowLayout {
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: queueView.currentKnown ? "Up next" : "Track list"; color: ThemeBackend.text; font.family: ThemeBackend.fontFamily; font.weight: Font.DemiBold; font.pixelSize: root.s(12) }
                IconButton { size: root.s(26); buttonIcon: "󰑓"; iconFontSize: root.s(14); cornerRadius: root.s(8); accentColor: ThemeBackend.surface1; textColor: ThemeBackend.text; onClicked: queueView.refresh() }
            }
            Item {
                Layout.fillWidth: true; Layout.fillHeight: true
                Text { anchors.centerIn: parent; width: parent.width - root.s(20); horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; visible: !queueView.tracks.length; text: !queueView.loaded ? "Loading…" : (!root.targetPlayer ? "No active media player" : (queueView.available ? "No upcoming tracks" : "This player doesn’t expose a track list")); color: ThemeBackend.subtext0; font.family: ThemeBackend.fontFamily; font.pixelSize: root.s(11) }
                ListView {
                    id: list; anchors.fill: parent; clip: true; spacing: root.s(4); model: queueView.tracks
                    delegate: Rectangle {
                        required property var modelData
                        width: list.width; height: root.s(44); radius: root.s(9); color: ma.containsMouse ? Qt.alpha(ThemeBackend.text, 0.1) : "transparent"
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: root.s(8); anchors.rightMargin: root.s(8); spacing: root.s(9)
                            Text { text: "󰎆"; font.family: ThemeBackend.iconFont; font.pixelSize: root.s(16); color: ThemeBackend.subtext0 }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 0
                                Text { Layout.fillWidth: true; text: modelData.title; elide: Text.ElideRight; color: ThemeBackend.text; font.family: ThemeBackend.fontFamily; font.pixelSize: root.s(11); font.weight: Font.DemiBold }
                                Text { Layout.fillWidth: true; text: modelData.artist; elide: Text.ElideRight; visible: text !== ""; color: ThemeBackend.subtext0; font.family: ThemeBackend.fontFamily; font.pixelSize: root.s(10) }
                            }
                        }
                        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (!goTo.running && queueView.currentBus) { goTo.command = ["python3", Caching.serpantinumDir + "/scripts/media_queue.py", queueView.currentBus, "goto", modelData.id]; goTo.running = true } } }
                    }
                }
            }
        }
    }
}
