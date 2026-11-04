import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "."

Item {
    id: dashboard
    property bool active: false
    property int selectedProvider: 0
    property var snapshot: ({})
    property string updated: ""
    property string error: ""
    function refresh() { if (!refreshProcess.running) refreshProcess.running=true; }
    onActiveChanged: if (active) refresh()
    Timer { interval:60000; running:dashboard.active; repeat:true; onTriggered:dashboard.refresh() }
    Process {
        id: refreshProcess
        command: ["python3", Quickshell.env("HOME") + "/.config/serpantinum/codex-usage/usage.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let result = JSON.parse(text);
                    if (result.snapshot) dashboard.snapshot = result.snapshot;
                    if (result.updated) dashboard.updated = result.updated;
                    dashboard.error = result.error || "";
                } catch (e) { dashboard.error = "Could not read Codex usage"; }
            }
        }
    }
    function remaining(w) { return w && Number.isFinite(w.usedPercent) ? Math.max(0,Math.min(100,100-w.usedPercent)) : -1; }
    function reset(w) { return w && w.resetsAt ? Qt.formatDateTime(new Date(w.resetsAt*1000),"ddd, d MMM · h:mm AP") : "Reset time unavailable"; }
    ColumnLayout {
        anchors.fill:parent; anchors.margins:20; spacing:12
        Row {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            spacing: 20
            Repeater {
                model: ["Codex", "Claude Code"]
                delegate: Item {
                    id: providerTab
                    required property int index
                    required property string modelData
                    width: providerLabel.implicitWidth
                    height: 28
                    Text {
                        id: providerLabel
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -2
                        text: providerTab.modelData
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: 12
                        font.weight: dashboard.selectedProvider === providerTab.index ? Font.DemiBold : Font.Normal
                        color: dashboard.selectedProvider === providerTab.index || providerMouse.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width; height: 2; radius: 1
                        color: ThemeBackend.mauve
                        opacity: dashboard.selectedProvider === providerTab.index ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }
                    MouseArea {
                        id: providerMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: dashboard.selectedProvider = providerTab.index
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth:true
            Text { text:"Your usage"; color:ThemeBackend.text; font.pixelSize:23; font.weight:Font.DemiBold; Layout.fillWidth:true }
            CodexActionButton { visible: dashboard.selectedProvider === 0; text:"↻"; implicitWidth:30; onClicked:dashboard.refresh() }
        }
        Repeater {
            model: dashboard.selectedProvider === 0 ? [{w:dashboard.snapshot.primary || null,title:"Session",accent:ThemeBackend.mauve}, {w:dashboard.snapshot.secondary || null,title:"Weekly",accent:ThemeBackend.teal}] : []
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth:true; Layout.fillHeight:true
                radius:15
                color:Qt.alpha(modelData.accent,0.065)
                border.width:1; border.color:Qt.alpha(modelData.accent,0.15)
                ColumnLayout {
                    anchors.fill:parent; anchors.margins:14; spacing:5
                    RowLayout {
                        Layout.fillWidth:true
                        Text { text:modelData.title; color:ThemeBackend.text; font.pixelSize:12; font.bold:true; Layout.fillWidth:true }
                        Text { text:modelData.w && modelData.w.windowDurationMins ? (modelData.w.windowDurationMins===10080 ? "7 DAYS" : modelData.w.windowDurationMins/60+" HOURS") : ""; color:ThemeBackend.subtext0; font.pixelSize:9; font.letterSpacing:1 }
                    }
                    RowLayout {
                        spacing:7
                        Text { text:dashboard.remaining(modelData.w)<0 ? "—" : Math.round(dashboard.remaining(modelData.w))+"%"; font.pixelSize:32; font.weight:Font.DemiBold; color:ThemeBackend.text }
                        Text { text:"remaining"; color:ThemeBackend.subtext0; font.pixelSize:11; Layout.alignment:Qt.AlignBottom; Layout.bottomMargin:6 }
                    }
                    Rectangle {
                        Layout.fillWidth:true; height:5; radius:3; color:Qt.alpha(modelData.accent,0.15)
                        Rectangle { width:parent.width*Math.max(0,dashboard.remaining(modelData.w))/100; height:parent.height; radius:3; color:modelData.accent }
                    }
                    Text { text:"Resets "+dashboard.reset(modelData.w); color:ThemeBackend.subtext0; font.pixelSize:10; wrapMode:Text.Wrap; Layout.fillWidth:true; Layout.minimumHeight: implicitHeight }
                }
            }
        }
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            visible: dashboard.selectedProvider === 1
            Column {
                anchors.centerIn: parent; width: parent.width; spacing: 8
                Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "Claude Code"; color: ThemeBackend.text; font.family: ThemeBackend.fontFamily; font.pixelSize: 15; font.weight: Font.DemiBold }
                Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; text: "Usage will appear here when connected."; color: ThemeBackend.subtext0; font.family: ThemeBackend.fontFamily; font.pixelSize: 11 }
            }
        }
        RowLayout {
            visible: dashboard.selectedProvider === 0
            Layout.fillWidth:true
            Rectangle {
                implicitWidth:plan.implicitWidth+16; implicitHeight:24; radius:12
                color:Qt.alpha(ThemeBackend.text,0.07)
                Text { id:plan; anchors.centerIn:parent; text:String(dashboard.snapshot.planType || "Codex").toUpperCase(); color:ThemeBackend.text; font.pixelSize:9; font.letterSpacing:1 }
            }
            Item { Layout.fillWidth:true }
            Text { text:dashboard.snapshot.credits && dashboard.snapshot.credits.hasCredits ? "Credits · "+dashboard.snapshot.credits.balance : "Plan allowance"; font.pixelSize:10; color:ThemeBackend.subtext0 }
        }
        Text { visible: dashboard.selectedProvider === 0; text:dashboard.error || (dashboard.updated ? "Updated "+dashboard.updated+" · local time" : "Fetching account limits…"); color:dashboard.error ? ThemeBackend.peach : ThemeBackend.subtext0; font.pixelSize:9; Layout.fillWidth:true; wrapMode:Text.Wrap }
        CodexActionButton {
            id: desktopButton
            visible: dashboard.selectedProvider === 0
            text: "Open desktop app →"
            textColor: hovered ? ThemeBackend.text : ThemeBackend.mauve
            implicitWidth: contentItem.implicitWidth
            implicitHeight: 24
            background: Item {}
            contentItem: Text {
                text: desktopButton.text
                color: desktopButton.textColor
                font.pixelSize: 11
                font.underline: desktopButton.hovered || desktopButton.activeFocus
                verticalAlignment: Text.AlignVCenter
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            onClicked: Quickshell.execDetached(["chatgpt"])
        }
    }
}
