import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import "../"
import "../reusables"

Rectangle {
    id: details
    required property var panel
    Layout.fillWidth: true
    Layout.preferredHeight: visible ? panel.s(155) : 0
    visible: panel.expandedQuickControl !== ""
    radius: panel.s(15); color: Qt.alpha(ThemeBackend.surface0, 0.75); clip: true
    property var items: []
    property var wifiDevice: null
    function refresh() {
        let rows = [];
        if (panel.expandedQuickControl === "wifi") {
            let devices = Networking.devices ? (Networking.devices.values || []) : [];
            let found = null;
            for (let d of devices) if (d && d.type === DeviceType.Wifi) { found = d; break; }
            if (wifiDevice && wifiDevice !== found) wifiDevice.scannerEnabled = false;
            wifiDevice = found;
            if (found) found.scannerEnabled = details.visible && panel.expandedQuickControl === "wifi" && panel.wifiRadioEnabled;
            let nets = found && found.networks ? (found.networks.values || []) : [];
            for (let n of nets) if (n && n.name) rows.push({object: n, name: n.name, connected: !!n.connected, known: !!n.known, security: n.security || 0, detail: n.connected ? "Connected" : Math.round((n.signalStrength || 0) * 100) + "%"});
            rows.sort((a,b) => Number(b.connected)-Number(a.connected) || Number(b.detail.replace('%',''))-Number(a.detail.replace('%','')));
        } else if (panel.expandedQuickControl === "bt") {
            let adapter = Bluetooth.defaultAdapter;
            let devs = adapter && adapter.devices ? (adapter.devices.values || []) : [];
            for (let d of devs) if (d && (d.paired || d.bonded || d.connected)) rows.push({object: d, name: d.deviceName || d.name || d.address, connected: !!d.connected, detail: d.connected ? (d.batteryAvailable ? "Connected · " + Math.round(d.battery*100) + "%" : "Connected") : "Paired"});
            rows.sort((a,b) => Number(b.connected)-Number(a.connected) || a.name.localeCompare(b.name));
        }
        items = rows;
    }
    onVisibleChanged: {
        if (visible) refresh();
        else if (wifiDevice) wifiDevice.scannerEnabled = false;
    }
    Component.onDestruction: if (wifiDevice) wifiDevice.scannerEnabled = false
    Connections {
        target: panel
        function onExpandedQuickControlChanged() {
            if (panel.expandedQuickControl !== "wifi" && details.wifiDevice) details.wifiDevice.scannerEnabled = false;
            details.refresh();
        }
    }
    Timer { running: details.visible; repeat: true; interval: 2500; onTriggered: details.refresh() }
    ColumnLayout {
        anchors.fill: parent; anchors.margins: panel.s(10); spacing: panel.s(5)
        RowLayout {
            Layout.fillWidth: true
            Text { Layout.fillWidth: true; text: panel.expandedQuickControl === "wifi" ? "Wi-Fi networks" : "Bluetooth devices"; color: ThemeBackend.text; font.family: ThemeBackend.fontFamily; font.weight: Font.DemiBold; font.pixelSize: panel.s(12) }
            ClickButton { Layout.preferredHeight: panel.s(24); buttonText: "More…"; textFontSize: panel.s(10); bgOpacity: 0.4; accentColor: ThemeBackend.surface1; textColor: ThemeBackend.text; onClicked: { let mode=panel.expandedQuickControl; panel.closeAnim.start(); Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/qs_manager.sh", "toggle", "network", mode]) } }
            IconButton { size: panel.s(24); buttonIcon: "󰅖"; iconFontSize: panel.s(13); accentColor: ThemeBackend.surface1; textColor: ThemeBackend.text; onClicked: panel.expandedQuickControl = "" }
        }
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            Text { anchors.centerIn: parent; visible: details.items.length === 0; text: panel.expandedQuickControl === "wifi" ? (panel.wifiRadioEnabled ? "No networks found" : "Wi-Fi is off") : (panel.btRadioEnabled ? "No paired devices" : "Bluetooth is off"); color: ThemeBackend.subtext0; font.family: ThemeBackend.fontFamily; font.pixelSize: panel.s(11) }
            ListView {
                id: list; anchors.fill: parent; clip: true; spacing: panel.s(3); model: details.items
                delegate: Rectangle {
                    required property var modelData
                    width: list.width; height: panel.s(34); radius: panel.s(8)
                    color: ma.containsMouse ? Qt.alpha(ThemeBackend.text, 0.12) : "transparent"
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: panel.s(8); anchors.rightMargin: panel.s(8); spacing: panel.s(8)
                        Text { text: panel.expandedQuickControl === "wifi" ? "󰤨" : "󰂯"; color: ThemeBackend.text; font.family: ThemeBackend.iconFont; font.pixelSize: panel.s(15) }
                        Text { Layout.fillWidth: true; text: modelData.name; elide: Text.ElideRight; color: ThemeBackend.text; font.family: ThemeBackend.fontFamily; font.pixelSize: panel.s(11) }
                        Text { text: modelData.detail; color: ThemeBackend.subtext0; font.family: ThemeBackend.fontFamily; font.pixelSize: panel.s(10) }
                    }
                    MouseArea {
                        id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            let item=modelData; if (!item.object) return;
                            if (panel.expandedQuickControl === "bt") { if (item.connected) item.object.disconnect(); else item.object.connect(); }
                            else if (!item.connected) {
                                if (item.known || item.security === 0) item.object.connect();
                                else { panel.closeAnim.start(); Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/qs_manager.sh", "open", "network", "wifi"]); }
                            }
                            refreshDelay.restart();
                        }
                    }
                }
            }
        }
    }
    Timer { id: refreshDelay; interval: 700; onTriggered: details.refresh() }
}
