import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../"
import "../../reusables"

Rectangle {
    id: section
    required property var tab
    readonly property var rootObj: tab.rootObj
    readonly property string scriptPath: (Caching.serpantinumDir || (Caching.home + "/.local/share/serpantinum/src")) + "/scripts/desktop-presets.py"
    property var presets: []
    property string statusMessage: ""
    property bool statusError: false
    property string actionName: ""
    property string actionOutput: ""
    property string actionError: ""

    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + rootObj.s(24)
    radius: ThemeBackend.borderRadius
    color: glass.active ? "transparent" : Qt.alpha(ThemeBackend.surface0, 0.4)
    clip: true

    function refresh() {
        if (!listProcess.running) listProcess.running = true;
    }
    function runAction(action, name) {
        if (actionProcess.running || !name) return;
        actionName = action;
        actionOutput = "";
        actionError = "";
        statusMessage = action === "save" ? "Saving desktop preset…" : "Applying desktop preset…";
        statusError = false;
        actionProcess.command = ["python3", scriptPath, action, name];
        actionProcess.running = true;
    }

    Component.onCompleted: refresh()
    Connections {
        target: section.tab
        function onVisibleChanged() { if (section.tab.visible) section.refresh(); }
    }
    Process {
        id: listProcess
        command: ["python3", section.scriptPath, "list"]
        stdout: StdioCollector {
            onStreamFinished: section.presets = text.trim() ? text.trim().split("\n") : []
        }
        onExited: function(code) {
            if (code !== 0) {
                section.statusError = true;
                section.statusMessage = "Could not load desktop presets.";
            }
        }
    }
    Process {
        id: actionProcess
        command: []
        stdout: StdioCollector { onStreamFinished: section.actionOutput = text.trim() }
        stderr: StdioCollector { onStreamFinished: section.actionError = text.trim() }
        onExited: function(code) {
            section.statusError = code !== 0;
            if (code === 0) {
                section.statusMessage = section.actionName === "save" ? "Desktop preset saved." : "Desktop preset applied. A backup was created.";
                if (section.actionName === "save") nameInput.text = "";
                section.refresh();
            } else {
                section.statusMessage = section.actionError || "Could not " + section.actionName + " desktop preset.";
            }
        }
    }
    GlassFill {
        id: glass
        anchors.fill: parent
        radius: parent.radius
        tintColor: Qt.alpha(ThemeBackend.surface0, 0.4)
        tintAmount: 0.25
    }
    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: rootObj.s(12)
        spacing: rootObj.s(8)

        SettingsRow {
            rootObj: section.rootObj
            settingId: "desktop_presets"
            icon: "󰍹"
            title: "Desktop presets"
            description: "Save and switch wallpaper, theme, bar, dock and widgets"
            searchKeywords: "desktop preset layout wallpaper dock bar widgets save apply"
            baseColor: "transparent"
            hoverColor: "transparent"
            borderWidth: 0
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: rootObj.s(8)
            Input {
                id: nameInput
                Layout.fillWidth: true
                Layout.preferredHeight: rootObj.s(32)
                placeholderText: "New preset name"
                maximumLength: 64
                cornerRadius: ThemeBackend.borderRadius
                fontPixelSize: rootObj.s(12)
                onAccepted: function(value) { section.runAction("save", value.trim()); }
            }
            ClickButton {
                implicitHeight: rootObj.s(32)
                maxWidth: rootObj.s(130)
                cornerRadius: ThemeBackend.borderRadius
                buttonText: "Save"
                textFontSize: rootObj.s(12)
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.crust
                enabled: !actionProcess.running && nameInput.text.trim().length > 0
                onClicked: section.runAction("save", nameInput.text.trim())
            }
        }
        Text {
            Layout.fillWidth: true
            visible: section.presets.length === 0
            text: "No saved desktop presets yet."
            font.family: ThemeBackend.fontFamily
            font.pixelSize: rootObj.s(12)
            color: ThemeBackend.subtext0
        }
        Repeater {
            model: section.presets
            delegate: RowLayout {
                required property string modelData
                Layout.fillWidth: true
                spacing: rootObj.s(8)
                Text {
                    Layout.fillWidth: true
                    text: modelData
                    elide: Text.ElideRight
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(12)
                    color: ThemeBackend.text
                }
                ClickButton {
                    implicitHeight: rootObj.s(32)
                    maxWidth: rootObj.s(100)
                    cornerRadius: ThemeBackend.borderRadius
                    buttonText: "Apply"
                    textFontSize: rootObj.s(12)
                    accentColor: ThemeBackend.surface2
                    textColor: ThemeBackend.text
                    enabled: !actionProcess.running
                    onClicked: section.runAction("apply", modelData)
                }
            }
        }
        Text {
            Layout.fillWidth: true
            visible: section.statusMessage !== ""
            text: section.statusMessage
            wrapMode: Text.Wrap
            font.family: ThemeBackend.fontFamily
            font.pixelSize: rootObj.s(11)
            color: section.statusError ? ThemeBackend.red : ThemeBackend.subtext0
        }
    }
}
