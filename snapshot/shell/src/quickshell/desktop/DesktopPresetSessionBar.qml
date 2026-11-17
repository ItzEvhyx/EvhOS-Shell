import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../"

Rectangle {
    id: root
    signal navigate(string tab)
    signal arrange()
    property bool desktop: false
    property bool widgetEditor: false
    readonly property var session: DesktopPresets.session
    readonly property bool hasDialog: DesktopPresets.nameRequested || !!DesktopPresets.pendingAction || DesktopPresets.deleteName !== ""
    visible: DesktopPresets.editing || hasDialog
    implicitHeight: visible ? contents.implicitHeight + s(24) : 0
    color: ThemeBackend.mantle
    radius: desktop ? s(12) : 0
    border.width: 1
    border.color: Qt.alpha(ThemeBackend.mauve, 0.4)
    function s(value) { return Math.round(Scaler.s(value)); }

    ColumnLayout {
        id: contents
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.s(12)
        spacing: root.s(8)
        Text {
            Layout.fillWidth: true
            visible: !!root.session
            text: "Editing: " + (root.session ? (root.session.name || "New preset") : "")
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.s(13)
            font.bold: true
            color: ThemeBackend.text
            wrapMode: Text.Wrap
        }
        Text {
            Layout.fillWidth: true
            visible: !!root.session
            text: DesktopPresets.busy ? "Saving or restoring your desktop…" : (root.session && root.session.dirty
                  ? "Unsaved changes · " + root.session.changedSections.join(", ") : "Previewing · Saved preset stays unchanged until you save")
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.s(11)
            color: ThemeBackend.subtext0
            wrapMode: Text.Wrap
        }
        Flow {
            Layout.fillWidth: true
            spacing: root.s(6)
            visible: !!root.session && !root.hasDialog
            PresetAction { text: root.session && root.session.isNew ? "Save preset…" : "Save changes"; primary: true; enabled: !DesktopPresets.busy && !!root.session && (root.session.dirty || root.session.isNew); onClicked: DesktopPresets.save() }
            PresetAction { text: "Save as new…"; enabled: !DesktopPresets.busy; onClicked: DesktopPresets.openName("save", "") }
            PresetAction { text: "Discard"; enabled: !DesktopPresets.busy; onClicked: DesktopPresets.perform("discard", "") }
            PresetAction { text: "Arrange widgets"; visible: !root.widgetEditor; enabled: !DesktopPresets.busy; onClicked: root.arrange() }
        }
        Flow {
            Layout.fillWidth: true
            spacing: root.s(6)
            visible: !!root.session && !root.hasDialog
            Repeater {
                model: [{label: "Wallpaper & colors", tab: "theme"}, {label: "Bar", tab: "bar"}, {label: "Dock", tab: "dock"}, {label: "Widgets", tab: "display_widgets"}]
                PresetAction { required property var modelData; text: modelData.label; enabled: !DesktopPresets.busy; onClicked: root.navigate(modelData.tab) }
            }
        }
        Text {
            Layout.fillWidth: true
            visible: !!DesktopPresets.pendingAction && !DesktopPresets.nameRequested
            text: "Save your changes before switching?"
            wrapMode: Text.Wrap
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.s(13)
            color: ThemeBackend.text
        }
        Flow {
            Layout.fillWidth: true
            spacing: root.s(6)
            visible: !!DesktopPresets.pendingAction && !DesktopPresets.nameRequested
            PresetAction { text: "Save and continue"; primary: true; enabled: !DesktopPresets.busy; onClicked: DesktopPresets.resolvePending("save") }
            PresetAction { text: "Discard and continue"; enabled: !DesktopPresets.busy; onClicked: DesktopPresets.resolvePending("discard") }
            PresetAction { text: "Keep editing"; enabled: !DesktopPresets.busy; onClicked: DesktopPresets.resolvePending("cancel") }
        }
        Text {
            Layout.fillWidth: true
            visible: DesktopPresets.nameRequested
            text: DesktopPresets.nameAction === "rename" ? "Rename preset" : (DesktopPresets.nameAction === "duplicate" ? "Duplicate preset" : "Save as new preset")
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.s(12)
            color: ThemeBackend.text
        }
        TextField {
            id: nameField
            Layout.fillWidth: true
            Layout.preferredHeight: root.s(36)
            visible: DesktopPresets.nameRequested
            enabled: !DesktopPresets.busy
            maximumLength: 64
            placeholderText: "Preset name"
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.s(13)
            color: ThemeBackend.text
            placeholderTextColor: ThemeBackend.subtext0
            background: Rectangle { radius: root.s(6); color: ThemeBackend.surface0; border.width: 1; border.color: nameField.activeFocus ? ThemeBackend.mauve : ThemeBackend.surface2 }
            onAccepted: if (text.trim()) DesktopPresets.submitName(text)
            onVisibleChanged: if (visible) { text = DesktopPresets.nameAction === "rename" ? DesktopPresets.nameSource : ""; Qt.callLater(forceActiveFocus); }
        }
        Flow {
            Layout.fillWidth: true
            spacing: root.s(6)
            visible: DesktopPresets.nameRequested
            PresetAction { text: DesktopPresets.nameAction === "rename" ? "Rename" : "Save preset"; primary: true; enabled: !DesktopPresets.busy && nameField.text.trim().length > 0; onClicked: DesktopPresets.submitName(nameField.text) }
            PresetAction { text: "Cancel"; enabled: !DesktopPresets.busy; onClicked: { DesktopPresets.nameRequested = false; } }
        }
        Text {
            Layout.fillWidth: true
            visible: DesktopPresets.deleteName !== ""
            text: "Delete “" + DesktopPresets.deleteName + "”? Your current desktop will stay as it is."
            wrapMode: Text.Wrap
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.s(12)
            color: ThemeBackend.text
        }
        Flow {
            Layout.fillWidth: true
            spacing: root.s(6)
            visible: DesktopPresets.deleteName !== ""
            PresetAction { text: "Delete preset"; destructive: true; enabled: !DesktopPresets.busy; onClicked: DesktopPresets.perform("delete", DesktopPresets.deleteName) }
            PresetAction { text: "Cancel"; enabled: !DesktopPresets.busy; onClicked: DesktopPresets.deleteName = "" }
        }
        Text {
            Layout.fillWidth: true
            visible: DesktopPresets.message !== ""
            text: DesktopPresets.message
            wrapMode: Text.Wrap
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.s(11)
            color: DesktopPresets.error ? ThemeBackend.red : ThemeBackend.subtext0
        }
    }
}
