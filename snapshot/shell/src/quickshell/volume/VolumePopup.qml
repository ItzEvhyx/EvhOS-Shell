import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Effects
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../"
import "../reusables"

Item {
    id: window
    visible: false
    focus: true

    function s(val) {
        return Scaler.s(val);
    }

    function gotoTab(tabName) {
        if (!tabName) return;
        let t = tabName.toLowerCase();
        if (t === "output" || t === "outputs" || t === "sink" || t === "sinks") window.activeTab = "outputs";
        else if (t === "input" || t === "inputs" || t === "source" || t === "sources") window.activeTab = "inputs";
        else if (t === "app" || t === "apps" || t === "stream" || t === "streams") window.activeTab = "apps";
    }

    property var exitCallback: null

    function startExit(onFinished) {
        introAnim.stop();
        exitCallback = onFinished;
        exitAnim.restart();
    }

    function resetAndPlayIntro() {
        exitAnim.stop();
        introMain = 0;
        introHeader = 0;
        introContent = 0;
        introAnim.restart();
    }

    Timer {
        id: focusTimer
        interval: 50
        repeat: false
        onTriggered: window.forceActiveFocus()
    }

    onVisibleChanged: {
        if (visible) {
            forceActiveFocus();
            focusTimer.restart();
            resetAndPlayIntro();
        } else {
            introAnim.stop();
            exitAnim.stop();
            introMain = 0;
            introHeader = 0;
            introContent = 0;
        }
    }

    Component.onCompleted: {
        if (visible) {
            forceActiveFocus();
            focusTimer.restart();
            resetAndPlayIntro();
        }
    }

    Shortcut {
        sequence: "Tab"
        enabled: window.visible
        onActivated: {
            if (window.activeTab === "outputs") window.activeTab = "inputs";
            else if (window.activeTab === "inputs") window.activeTab = "apps";
            else window.activeTab = "outputs";
        }
    }

    property string activeTab: "outputs"


    readonly property color tabColor: {
        if (activeTab === "outputs") return ThemeBackend.blue;
        if (activeTab === "inputs") return ThemeBackend.mauve;
        return ThemeBackend.green;
    }

    readonly property string activeOutputName: {
        const sink = Audio.defaultSink;
        return sink && sink.name ? sink.name : "";
    }

    readonly property string activeInputName: {
        const source = Audio.defaultSource;
        return source && source.name ? source.name : "";
    }

    readonly property PwNode activeNode: {
        if (window.activeTab === "inputs") {
            return Audio.defaultSource || (Audio.inputs.length > 0 ? Audio.inputs[0] : null);
        } else if (window.activeTab === "apps") {
            return Audio.apps.length > 0 ? Audio.apps[0] : null;
        } else {
            return Audio.defaultSink || (Audio.outputs.length > 0 ? Audio.outputs[0] : null);
        }
    }

    readonly property string activeName: {
        if (!activeNode) return I18n.t("volumepopup.no_device");
        if (activeTab === "apps") return Audio.getNodeAppName(activeNode);
        return Audio.getNodeName(activeNode);
    }

    readonly property string activeDesc: {
        if (!activeNode) return "";
        if (activeTab === "apps") return I18n.t("volumepopup.master_output_volume");
        return Audio.getNodeSubDesc(activeNode);
    }

    readonly property int activeVol: activeNode && activeNode.audio ? Math.round(activeNode.audio.volume * 100) : 0
    readonly property bool activeMute: activeNode && activeNode.audio ? activeNode.audio.muted : false

    readonly property string activeIcon: {
        if (!activeNode) return "󰓃";
        if (activeTab === "inputs") return "󰍬";
        if (activeTab === "apps") return "󰎆";
        let desc = (Audio.getNodeName(activeNode) || "").toLowerCase();
        if (desc.indexOf("headset") !== -1 || desc.indexOf("headphones") !== -1) return "󰋎";
        return "󰓃";
    }

    property real introMain: 0
    property real introHeader: 0
    property real introContent: 0

    ParallelAnimation {
        id: introAnim
        running: false
        NumberAnimation { target: window; property: "introMain"; from: 0; to: 1.0; duration: 272; easing.type: Easing.OutExpo }
        SequentialAnimation {
            PauseAnimation { duration: 34 }
            NumberAnimation { target: window; property: "introHeader"; from: 0; to: 1.0; duration: 238; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        }
        SequentialAnimation {
            PauseAnimation { duration: 85 }
            NumberAnimation { target: window; property: "introContent"; from: 0; to: 1.0; duration: 272; easing.type: Easing.OutExpo }
        }
    }

    SequentialAnimation {
        id: exitAnim
        running: false
        ParallelAnimation {
            NumberAnimation { target: window; property: "introContent"; to: 0.0; duration: 150; easing.type: Easing.InCubic }
            SequentialAnimation {
                PauseAnimation { duration: 30 }
                NumberAnimation { target: window; property: "introHeader"; to: 0.0; duration: 160; easing.type: Easing.InBack }
            }
            SequentialAnimation {
                PauseAnimation { duration: 50 }
                NumberAnimation { target: window; property: "introMain"; to: 0.0; duration: 150; easing.type: Easing.InQuart }
            }
        }
        ScriptAction {
            script: {
                if (window.exitCallback) {
                    let cb = window.exitCallback;
                    window.exitCallback = null;
                    cb();
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: window.s(22)
        color: Qt.alpha(ThemeBackend.base, 0.78) // local translucent widget
        border.width: 1
        border.color: Qt.alpha(ThemeBackend.text, 0.12)
        clip: true
        opacity: introMain
        scale: 0.97 + 0.03 * introMain

        WallpaperBlur {
            z: -1
            anchors.fill: parent
            radius: parent.radius
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: window.s(20)
            spacing: window.s(14)

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: "Sound"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: window.s(21)
                    font.weight: Font.DemiBold
                    color: ThemeBackend.text
                }
                Text {
                    text: window.activeVol + "%"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: window.s(14)
                    font.weight: Font.DemiBold
                    color: ThemeBackend.subtext0
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: window.s(114)
                radius: window.s(16)
                color: Qt.alpha(ThemeBackend.surface0, 0.8)
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: window.s(14)
                    spacing: window.s(10)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: window.s(10)
                        Rectangle {
                            Layout.preferredWidth: window.s(38)
                            Layout.preferredHeight: window.s(38)
                            radius: window.s(12)
                            color: Qt.alpha(window.tabColor, 0.18)
                            Text { anchors.centerIn: parent; text: window.activeIcon; font.family: ThemeBackend.iconFont; font.pixelSize: window.s(20); color: "white" }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: window.s(2)
                            Text { Layout.fillWidth: true; text: window.activeName; elide: Text.ElideRight; font.family: ThemeBackend.fontFamily; font.weight: Font.DemiBold; font.pixelSize: window.s(13); color: ThemeBackend.text }
                            Text { Layout.fillWidth: true; text: window.activeDesc; elide: Text.ElideRight; font.family: ThemeBackend.fontFamily; font.pixelSize: window.s(10); color: ThemeBackend.subtext0 }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: window.s(10)
                        IconButton {
                            size: window.s(26); cornerRadius: window.s(8)
                            buttonIcon: window.activeMute || window.activeVol === 0 ? "󰖁" : "󰕾"
                            iconFontSize: window.s(16); accentColor: ThemeBackend.surface1; textColor: "white"
                            onClicked: if (window.activeNode) Audio.toggleMute(window.activeNode)
                        }
                        Draggable {
                            Layout.fillWidth: true; Layout.preferredHeight: window.s(14)
                            from: 0; to: 100; value: window.activeVol
                            backgroundColor: ThemeBackend.surface1
                            accentColor: window.activeMute ? ThemeBackend.surface2 : window.tabColor
                            gradColor1: accentColor; gradColor2: accentColor; gradColor3: accentColor
                            cornerRadius: window.s(7); handleSize: window.s(16)
                            onMoved: (val) => {
                                if (!window.activeNode) return;
                                let pct = Math.max(0, Math.min(100, Math.round(val)));
                                if (pct > 0 && window.activeMute) Audio.toggleMute(window.activeNode);
                                Audio.setVolume(window.activeNode, pct);
                            }
                        }
                    }
                }
            }
            Row {
                Layout.fillWidth: true
                Layout.preferredHeight: window.s(32)
                spacing: window.s(20)
                Repeater {
                    model: [I18n.t("volumepopup.tabs.outputs"), I18n.t("volumepopup.tabs.inputs"), I18n.t("volumepopup.tabs.streams")]
                    delegate: Item {
                        id: tab
                        required property int index
                        required property string modelData
                        readonly property bool selected: window.activeTab === (index === 0 ? "outputs" : (index === 1 ? "inputs" : "apps"))
                        width: label.implicitWidth
                        height: window.s(32)
                        Text {
                            id: label
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: -window.s(2)
                            text: tab.modelData
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: window.s(12)
                            font.weight: tab.selected ? Font.DemiBold : Font.Normal
                            color: tab.selected || tabMouse.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width; height: window.s(2); radius: height / 2
                            color: ThemeBackend.mauve
                            opacity: tab.selected ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }
                        MouseArea {
                            id: tabMouse; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.activeTab = index === 0 ? "outputs" : (index === 1 ? "inputs" : "apps")
                        }
                    }
                }
            }
            Text {
                text: window.activeTab === "outputs" ? I18n.t("volumepopup.tabs.outputs") : (window.activeTab === "inputs" ? I18n.t("volumepopup.tabs.inputs") : I18n.t("volumepopup.tabs.streams"))
                font.family: ThemeBackend.fontFamily; font.pixelSize: window.s(12); font.weight: Font.DemiBold
                color: ThemeBackend.subtext0
            }
            ListView {
                id: contentList
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true; spacing: window.s(6); boundsBehavior: Flickable.StopAtBounds
                model: window.activeTab === "outputs" ? Audio.outputs : (window.activeTab === "inputs" ? Audio.inputs : Audio.apps)
                Text {
                    anchors.centerIn: parent; visible: contentList.count === 0
                    text: I18n.t("volumepopup.no_active_streams")
                    font.family: ThemeBackend.fontFamily; font.pixelSize: window.s(12); color: ThemeBackend.overlay0
                }
                delegate: Rectangle {
                    id: device
                    required property var modelData
                    readonly property PwNode node: modelData
                    readonly property bool selected: node && (window.activeTab === "outputs" ? node.name === window.activeOutputName : (window.activeTab === "inputs" && node.name === window.activeInputName))
                    readonly property int volume: node && node.audio ? Math.round(node.audio.volume * 100) : 0
                    readonly property bool muted: node && node.audio ? node.audio.muted : false
                    width: contentList.width; height: window.s(84); radius: window.s(12)
                    color: deviceMouse.containsMouse ? ThemeBackend.surface1 : Qt.alpha(ThemeBackend.surface0, 0.62)
                    MouseArea {
                        id: deviceMouse; anchors.fill: parent; hoverEnabled: true
                        cursorShape: window.activeTab === "apps" ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: {
                            if (!device.node || device.selected) return;
                            if (window.activeTab === "outputs") Audio.setDefaultOutput(device.node);
                            else if (window.activeTab === "inputs") Audio.setDefaultInput(device.node);
                        }
                    }
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: window.s(10); spacing: window.s(5)
                        RowLayout {
                            Layout.fillWidth: true; spacing: window.s(9)
                            Text { text: window.activeTab === "inputs" ? "󰍬" : (window.activeTab === "apps" ? "󰎆" : "󰓃"); font.family: ThemeBackend.iconFont; font.pixelSize: window.s(17); color: "white" }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 0
                                Text { Layout.fillWidth: true; text: window.activeTab === "apps" ? Audio.getNodeAppName(device.node) : Audio.getNodeName(device.node); elide: Text.ElideRight; font.family: ThemeBackend.fontFamily; font.weight: Font.DemiBold; font.pixelSize: window.s(12); color: ThemeBackend.text }
                                Text { Layout.fillWidth: true; text: device.selected ? I18n.t("volumepopup.active_default") : Audio.getNodeSubDesc(device.node); elide: Text.ElideRight; font.family: ThemeBackend.fontFamily; font.pixelSize: window.s(10); color: ThemeBackend.subtext0 }
                            }
                            Text { visible: device.selected; text: "✓"; font.pixelSize: window.s(16); color: window.tabColor }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: window.s(8)
                            IconButton {
                                size: window.s(22); cornerRadius: window.s(7); iconFontSize: window.s(13)
                                buttonIcon: device.muted || device.volume === 0 ? "󰖁" : "󰕾"
                                accentColor: ThemeBackend.surface1; textColor: "white"
                                onClicked: if (device.node) Audio.toggleMute(device.node)
                            }
                            Draggable {
                                Layout.fillWidth: true; Layout.preferredHeight: window.s(12)
                                from: 0; to: 100; value: device.volume
                                backgroundColor: ThemeBackend.surface1
                                accentColor: device.muted ? ThemeBackend.surface2 : window.tabColor
                                gradColor1: accentColor; gradColor2: accentColor; gradColor3: accentColor
                                cornerRadius: window.s(6); handleSize: window.s(14)
                                onMoved: (val) => {
                                    if (!device.node) return;
                                    let pct = Math.max(0, Math.min(100, Math.round(val)));
                                    if (pct > 0 && device.muted) Audio.toggleMute(device.node);
                                    Audio.setVolume(device.node, pct);
                                }
                            }
                            Text { Layout.preferredWidth: window.s(32); horizontalAlignment: Text.AlignRight; text: device.volume + "%"; font.family: ThemeBackend.fontFamily; font.pixelSize: window.s(10); color: ThemeBackend.subtext0 }
                        }
                    }
                }
            }
        }
    }
}
