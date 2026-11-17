import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"
import "../../desktop"

Rectangle {
    id: section
    required property var tab
    readonly property var rootObj: tab.rootObj
    function s(value) { return rootObj.s(value); }
    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + s(24)
    radius: ThemeBackend.borderRadius
    color: Qt.alpha(ThemeBackend.surface0, 0.6)
    border.width: 1
    border.color: Qt.alpha(ThemeBackend.text, 0.08)
    Component.onCompleted: { DesktopPresets.viewers++; DesktopPresets.refresh(); }
    Component.onDestruction: DesktopPresets.viewers = Math.max(0, DesktopPresets.viewers - 1)
    Connections { target: section.tab; function onVisibleChanged() { if (section.tab.visible) DesktopPresets.refresh(); } }

    ColumnLayout {
        id: content
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: section.s(12) }
        spacing: section.s(12)
        SettingsRow {
            rootObj: section.rootObj
            settingId: "desktop_presets"
            icon: "󰍹"
            title: "Desktop presets"
            description: "Complete desktop layouts: wallpaper, appearance, bar, dock and widgets"
            searchKeywords: "desktop preset customize edit layout save apply theme"
            baseColor: "transparent"
            hoverColor: "transparent"
            borderWidth: 0
        }
        Text {
            Layout.fillWidth: true
            text: "Current desktop: " + (DesktopPresets.state.activeName || "Custom desktop")
                  + (DesktopPresets.state.modified ? " · Modified" : (DesktopPresets.state.activeName ? " · Saved" : " · Not saved"))
            font.family: ThemeBackend.fontFamily
            font.pixelSize: section.s(12)
            color: ThemeBackend.text
            wrapMode: Text.Wrap
        }
        Flow {
            Layout.fillWidth: true
            spacing: section.s(8)
            PresetAction { text: "+ Create preset"; primary: true; enabled: !DesktopPresets.busy; onClicked: DesktopPresets.request("begin", "") }
            PresetAction { text: "Save current as new…"; enabled: !DesktopPresets.busy; onClicked: DesktopPresets.openName("save", "") }
            PresetAction { text: "Undo switch"; enabled: !DesktopPresets.busy && DesktopPresets.state.canUndo; onClicked: DesktopPresets.request("undo", "") }
        }
        Text {
            Layout.fillWidth: true
            visible: DesktopPresets.state.presets.length === 0
            text: "No presets yet. Create one from your current desktop, customize it, then save."
            font.family: ThemeBackend.fontFamily
            font.pixelSize: section.s(12)
            color: ThemeBackend.subtext0
            wrapMode: Text.Wrap
        }
        GridLayout {
            Layout.fillWidth: true
            columns: width >= section.s(620) ? 2 : 1
            columnSpacing: section.s(12)
            rowSpacing: section.s(12)
            Repeater {
                model: DesktopPresets.state.presets
                delegate: Rectangle {
                    id: card
                    required property var modelData
                    property bool moreOpen: false
                    readonly property bool active: modelData.name === DesktopPresets.state.activeName
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    implicitHeight: preview.height + body.implicitHeight + section.s(24)
                    radius: section.s(10)
                    color: ThemeBackend.mantle
                    border.width: card.active ? 2 : 1
                    border.color: card.active ? Qt.alpha(ThemeBackend.mauve, 0.7) : ThemeBackend.surface1
                    clip: true
                    Rectangle {
                        id: preview
                        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
                        height: section.s(130)
                        color: ThemeBackend.surface0
                        clip: true
                        Image {
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 640
                            source: /\.(png|jpe?g|webp|bmp)$/i.test(card.modelData.wallpaper || "")
                                ? "file://" + card.modelData.wallpaper.split("/").map(encodeURIComponent).join("/") : ""
                        }
                        Rectangle { anchors.fill: parent; color: Qt.alpha(ThemeBackend.crust, 0.18) }
                        Rectangle {
                            readonly property string position: card.modelData.barPosition
                            readonly property bool vertical: position === "left" || position === "right"
                            readonly property real fraction: Math.max(0.15, Math.min(1, (card.modelData.barWidth || 100) / 100))
                            width: vertical ? section.s(12) : parent.width * fraction
                            height: vertical ? parent.height * fraction : section.s(12)
                            x: vertical ? (position === "right" ? parent.width - width : 0) : (parent.width - width) / 2
                            y: vertical ? (parent.height - height) / 2 : (position === "bottom" ? parent.height - height : 0)
                            radius: section.s(3)
                            color: ThemeBackend.crust
                            opacity: 0.95
                        }
                        Rectangle {
                            visible: card.modelData.dockEnabled
                            readonly property string position: card.modelData.dockPosition
                            readonly property bool vertical: position === "left" || position === "right"
                            width: vertical ? section.s(12) : parent.width * 0.25
                            height: vertical ? parent.height * 0.4 : section.s(12)
                            x: vertical ? (position === "right" ? parent.width - width - 6 : 6) : (parent.width - width) / 2
                            y: vertical ? (parent.height - height) / 2 : (position === "top" ? 6 : parent.height - height - 6)
                            radius: section.s(4)
                            color: ThemeBackend.mantle
                            border.width: 1
                            border.color: ThemeBackend.overlay0
                        }
                        Text {
                            anchors { right: parent.right; bottom: parent.bottom; margins: section.s(8) }
                            text: "Layout preview"
                            color: "white"
                            style: Text.Outline
                            styleColor: "black"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: section.s(10)
                        }
                    }
                    ColumnLayout {
                        id: body
                        anchors { top: preview.bottom; left: parent.left; right: parent.right; margins: section.s(12) }
                        spacing: section.s(8)
                        Text {
                            Layout.fillWidth: true
                            text: card.modelData.name
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: section.s(13)
                            font.bold: true
                            color: ThemeBackend.text
                            wrapMode: Text.Wrap
                        }
                        Text {
                            Layout.fillWidth: true
                            text: (card.active ? "Active · " : "") + card.modelData.barPosition + " bar · "
                                  + (card.modelData.dockEnabled ? card.modelData.dockPosition + " dock" : "Dock hidden")
                                  + " · " + card.modelData.widgetCount + (card.modelData.widgetCount === 1 ? " widget" : " widgets")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: section.s(11)
                            color: ThemeBackend.subtext0
                            wrapMode: Text.Wrap
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: card.modelData.missingAssets.length > 0
                            text: "Wallpaper unavailable · Restore the file before applying"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: section.s(11)
                            color: ThemeBackend.red
                            wrapMode: Text.Wrap
                        }
                        Flow {
                            Layout.fillWidth: true
                                            spacing: section.s(6)
                            PresetAction { text: card.active && !DesktopPresets.state.modified ? "Active" : "Apply"; enabled: !DesktopPresets.busy && !(card.active && !DesktopPresets.state.modified) && card.modelData.missingAssets.length === 0; onClicked: DesktopPresets.request("apply", card.modelData.name) }
                            PresetAction { text: "Customize"; enabled: !DesktopPresets.busy && card.modelData.missingAssets.length === 0; onClicked: DesktopPresets.request("begin", card.modelData.name) }
                            PresetAction { text: card.moreOpen ? "Less" : "More"; onClicked: card.moreOpen = !card.moreOpen }
                        }
                        Flow {
                            Layout.fillWidth: true
                                            spacing: section.s(6)
                            visible: card.moreOpen
                            enabled: !DesktopPresets.busy && !DesktopPresets.editing
                            PresetAction { text: "Rename"; onClicked: DesktopPresets.openName("rename", card.modelData.name) }
                            PresetAction { text: "Duplicate"; onClicked: DesktopPresets.openName("duplicate", card.modelData.name) }
                            PresetAction { text: "Delete"; destructive: true; onClicked: DesktopPresets.deleteName = card.modelData.name }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: card.moreOpen && DesktopPresets.editing
                            text: "Finish editing to rename, duplicate or delete presets."
                            color: ThemeBackend.subtext0
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: section.s(11)
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }
        Text {
            Layout.fillWidth: true
            visible: DesktopPresets.message !== ""
            text: DesktopPresets.message
            color: DesktopPresets.error ? ThemeBackend.red : ThemeBackend.subtext0
            font.family: ThemeBackend.fontFamily
            font.pixelSize: section.s(11)
            wrapMode: Text.Wrap
        }
        Text {
            Layout.fillWidth: true
            visible: DesktopPresets.state.warnings.length > 0
            text: DesktopPresets.state.warnings.join("\n")
            color: ThemeBackend.red
            font.family: ThemeBackend.fontFamily
            font.pixelSize: section.s(11)
            wrapMode: Text.Wrap
        }
    }
}
