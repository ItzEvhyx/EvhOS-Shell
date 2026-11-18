import QtQuick
import QtQuick.Layouts
import "../../"
import "../../desktop"

Rectangle {
    id: section
    required property var tab
    readonly property var rootObj: tab.rootObj
    property bool showHistory: false
    property string expandedTheme: ""
    property bool revealed: false
    function syncPresets() {
        let desired = DesktopPresets.state.presets || [];
        let names = desired.map(p => p.name);
        for (let i = presetModel.count - 1; i >= 0; --i) {
            if (!names.includes(presetModel.get(i).key))
                presetModel.remove(i);
        }
        for (let i = 0; i < desired.length; ++i) {
            let found = -1;
            for (let j = i; j < presetModel.count; ++j)
                if (presetModel.get(j).key === desired[i].name) {
                    found = j;
                    break;
                }
            let payload = JSON.stringify(desired[i]);
            if (found < 0)
                presetModel.insert(i, {
                    key: desired[i].name,
                    payload: payload
                });
            else {
                if (found !== i)
                    presetModel.move(found, i, 1);
                if (presetModel.get(i).payload !== payload)
                    presetModel.setProperty(i, "payload", payload);
            }
        }
        if (expandedTheme && !names.includes(expandedTheme))
            expandedTheme = "";
    }
    ListModel {
        id: presetModel
    }
    Connections {
        target: DesktopPresets
        function onStateChanged() {
            section.syncPresets();
        }
    }
    opacity: revealed ? 1 : 0
    transform: Translate {
        y: section.revealed ? 0 : section.s(12)
        Behavior on y {
            NumberAnimation {
                duration: 240
                easing.type: Easing.OutCubic
            }
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }
    onVisibleChanged: {
        if (visible)
            Qt.callLater(() => revealed = true);
        else
            revealed = false;
    }
    function s(value) {
        return rootObj.s(value);
    }
    function localTime(value) {
        if (!value)
            return "Earlier desktop";
        let date = new Date(value);
        return isNaN(date.getTime()) ? "Earlier desktop" : date.toLocaleString(Qt.locale(), "d MMM, h:mm AP");
    }
    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + s(8)
    radius: s(18)
    color: "transparent"
    Component.onCompleted: {
        syncPresets();
        DesktopPresets.viewers++;
        DesktopPresets.refresh();
        Qt.callLater(() => revealed = true);
    }
    Component.onDestruction: DesktopPresets.viewers = Math.max(0, DesktopPresets.viewers - 1)
    Connections {
        target: section.tab
        function onVisibleChanged() {
            if (section.tab.visible)
                DesktopPresets.refresh();
        }
    }

    component Copy: Text {
        font.family: ThemeBackend.fontFamily
        font.pixelSize: section.s(12)
        color: ThemeBackend.subtext0
        wrapMode: Text.Wrap
    }
    ColumnLayout {
        id: content
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        spacing: section.s(18)
        RowLayout {
            Layout.fillWidth: true
            Copy {
                text: "Your desktops"
                color: ThemeBackend.text
                font.family: "sans-serif"
                font.pixelSize: section.s(22)
                font.bold: true
                Layout.fillWidth: true
            }
            PresetAction {
                text: "+ New theme"
                primary: true
                enabled: !DesktopPresets.busy
                onClicked: DesktopPresets.openName("save", "")
            }
        }
        Copy {
            Layout.fillWidth: true
            text: "Create a look, make it yours, and return to it whenever you like."
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: currentBody.implicitHeight + section.s(28)
            radius: section.s(16)
            color: Qt.alpha(ThemeBackend.text, 0.045)
            border.width: 1
            border.color: Qt.alpha(ThemeBackend.text, 0.12)
            ColumnLayout {
                id: currentBody
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: section.s(14)
                }
                spacing: section.s(12)
                RowLayout {
                    Layout.fillWidth: true
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: section.s(3)
                        Copy {
                            text: "ACTIVE THEME"
                            font.family: "sans-serif"
                            font.pixelSize: section.s(10)
                            font.bold: true
                            font.letterSpacing: section.s(1.4)
                        }
                        Copy {
                            Layout.fillWidth: true
                            text: DesktopPresets.state.activeName || "Custom desktop"
                            color: ThemeBackend.text
                            font.family: "sans-serif"
                            font.pixelSize: section.s(19)
                            font.bold: true
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                        }
                    }
                    Rectangle {
                        implicitWidth: statusLabel.implicitWidth + section.s(24)
                        implicitHeight: section.s(28)
                        radius: height / 2
                        color: Qt.alpha(DesktopPresets.autosaveError ? ThemeBackend.red : ThemeBackend.text, DesktopPresets.state.modified ? 0.12 : 0.055)
                        Behavior on color {
                            ColorAnimation {
                                duration: 180
                            }
                        }
                        border.width: 1
                        border.color: Qt.alpha(ThemeBackend.text, 0.13)
                        Copy {
                            id: statusLabel
                            anchors.centerIn: parent
                            text: DesktopPresets.autosaveRunning ? "Saving…" : DesktopPresets.autosaveError ? "Needs attention" : DesktopPresets.state.modified ? "Saving changes…" : (DesktopPresets.state.activeName ? "Saved automatically" : "Not saved yet")
                            color: ThemeBackend.text
                            font.family: "sans-serif"
                            font.pixelSize: section.s(11)
                            font.bold: true
                        }
                    }
                }
                Copy {
                    Layout.fillWidth: true
                    text: DesktopPresets.state.modified ? "Changed: " + DesktopPresets.changedText() : (DesktopPresets.state.activeName ? "Visual changes in Settings or the terminal save to this theme automatically." : "New theme saves this desktop as a separate look.")
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: section.s(8)
                    PresetAction {
                        text: DesktopPresets.autosaveError ? "Resolve save…" : "Save now"
                        primary: true
                        enabled: !DesktopPresets.busy && !DesktopPresets.autosaveRunning && !!DesktopPresets.state.activeName && (DesktopPresets.state.modified || DesktopPresets.autosaveError !== "")
                        onClicked: {
                            if (DesktopPresets.autosaveError)
                                DesktopPresets.save();
                            else
                                DesktopPresets.saveNow();
                        }
                    }
                    PresetAction {
                        text: "Undo last switch"
                        enabled: !DesktopPresets.busy && DesktopPresets.state.canUndo
                        onClicked: DesktopPresets.request("undo", "")
                    }
                    PresetAction {
                        text: section.showHistory ? "Hide history" : "History"
                        enabled: !DesktopPresets.busy
                        onClicked: {
                            section.showHistory = !section.showHistory;
                            if (section.showHistory)
                                DesktopPresets.refresh();
                        }
                    }
                }
            }
        }

        Item {
            objectName: "presetHistoryDrawer"
            Layout.fillWidth: true
            implicitHeight: section.showHistory ? historyBody.implicitHeight : 0
            visible: section.showHistory || implicitHeight > 0.1
            clip: true
            opacity: section.showHistory ? 1 : 0
            Behavior on implicitHeight {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                }
            }
            ColumnLayout {
                id: historyBody
                width: parent.width
                spacing: section.s(8)
                Copy {
                    text: "Recovery history"
                    color: ThemeBackend.text
                    font.bold: true
                }
                Copy {
                    Layout.fillWidth: true
                    text: "A desktop snapshot is kept before each switch. Saving changes also keeps the previous saved version."
                }
                Copy {
                    visible: !(DesktopPresets.state.history || []).length
                    text: "Your first snapshot will appear after a switch or save."
                }
                Repeater {
                    model: (DesktopPresets.state.history || []).slice(0, 8)
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: historyRow.implicitHeight + section.s(20)
                        radius: section.s(10)
                        color: Qt.alpha(ThemeBackend.text, 0.035)
                        RowLayout {
                            id: historyRow
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: section.s(10)
                            }
                            spacing: section.s(12)
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: section.s(3)
                                Copy {
                                    Layout.fillWidth: true
                                    text: modelData.reason
                                    color: ThemeBackend.text
                                    font.bold: true
                                    elide: Text.ElideRight
                                    wrapMode: Text.NoWrap
                                }
                                Copy {
                                    text: section.localTime(modelData.createdAt) + (modelData.name ? " · " + modelData.name : "")
                                    font.pixelSize: section.s(11)
                                }
                            }
                            PresetAction {
                                text: "Restore…"
                                enabled: !DesktopPresets.busy
                                onClicked: DesktopPresets.request("restore", modelData.id)
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Copy {
                text: "Saved themes"
                color: ThemeBackend.text
                font.bold: true
                Layout.fillWidth: true
            }
            Copy {
                text: String(DesktopPresets.state.presets.length)
                font.family: "sans-serif"
                font.bold: true
            }
        }
        Copy {
            Layout.fillWidth: true
            visible: DesktopPresets.state.presets.length === 0
            text: "Choose New theme to save your current desktop. Nothing changes until you switch."
        }
        GridLayout {
            Layout.fillWidth: true
            columns: width >= section.s(650) ? 2 : 1
            columnSpacing: section.s(14)
            rowSpacing: section.s(14)
            Repeater {
                model: presetModel
                delegate: Rectangle {
                    id: card
                    objectName: "presetThemeCard_" + modelData.name
                    required property string payload
                    readonly property var modelData: JSON.parse(payload)
                    readonly property bool moreOpen: section.expandedTheme === modelData.name
                    HoverHandler {
                        id: cardHover
                        enabled: !DesktopPresets.busy
                    }
                    transform: Translate {
                        y: cardHover.hovered ? -section.s(2) : 0
                        Behavior on y {
                            NumberAnimation {
                                duration: 170
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                    readonly property bool active: modelData.name === DesktopPresets.state.activeName
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    implicitHeight: preview.height + cardBody.implicitHeight + section.s(32)
                    Behavior on implicitHeight {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }
                    radius: section.s(16)
                    color: Qt.alpha(ThemeBackend.mantle, cardHover.hovered ? 0.98 : 0.9)
                    Behavior on color {
                        ColorAnimation {
                            duration: 170
                        }
                    }
                    border.width: card.active ? 2 : 1
                    border.color: Qt.alpha(card.active ? ThemeBackend.mauve : ThemeBackend.text, card.active ? 0.7 : cardHover.hovered ? 0.3 : 0.12)
                    Behavior on border.color {
                        ColorAnimation {
                            duration: 180
                        }
                    }
                    clip: true
                    Rectangle {
                        id: preview
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: 2
                        }
                        height: section.s(142)
                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: card.modelData.surfaceColor || "#252932"
                            }
                            GradientStop {
                                position: 1
                                color: card.modelData.baseColor || "#101216"
                            }
                        }
                        clip: true
                        Image {
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 220
                                }
                            }
                            sourceSize.width: 560
                            source: card.modelData.preview ? "file://" + card.modelData.preview.split("/").map(encodeURIComponent).join("/") + "?rev=" + (card.modelData.previewRevision || "0") : ""
                        }
                        Rectangle {
                            anchors.fill: parent
                            color: Qt.alpha(ThemeBackend.crust, 0.16)
                        }
                        Rectangle {
                            readonly property string position: card.modelData.barPosition
                            readonly property bool vertical: position === "left" || position === "right"
                            readonly property real fraction: Math.max(0.18, Math.min(0.94, (card.modelData.barWidth || 100) / 100))
                            width: vertical ? section.s(8) : parent.width * fraction
                            height: vertical ? parent.height * 0.8 : section.s(8)
                            x: vertical ? (position === "right" ? parent.width - width - 8 : 8) : (parent.width - width) / 2
                            y: vertical ? (parent.height - height) / 2 : (position === "bottom" ? parent.height - height - 8 : 8)
                            radius: section.s(4)
                            color: Qt.alpha(card.modelData.accentColor || "white", 0.7)
                        }
                        Rectangle {
                            visible: card.modelData.dockEnabled
                            readonly property string position: card.modelData.dockPosition
                            readonly property bool vertical: position === "left" || position === "right"
                            width: vertical ? section.s(10) : parent.width * 0.25
                            height: vertical ? parent.height * 0.4 : section.s(10)
                            x: vertical ? (position === "right" ? parent.width - width - 10 : 10) : (parent.width - width) / 2
                            y: vertical ? (parent.height - height) / 2 : (position === "top" ? 10 : parent.height - height - 10)
                            radius: section.s(5)
                            color: Qt.alpha(card.modelData.accentColor || "white", 0.25)
                            border.width: 1
                            border.color: Qt.alpha(card.modelData.accentColor || "white", 0.5)
                        }
                        Rectangle {
                            visible: card.active
                            anchors {
                                right: parent.right
                                top: parent.top
                                margins: section.s(10)
                            }
                            width: activeLabel.implicitWidth + section.s(16)
                            height: section.s(24)
                            radius: height / 2
                            color: Qt.alpha(ThemeBackend.crust, 0.8)
                            Copy {
                                id: activeLabel
                                anchors.centerIn: parent
                                text: "✓ Active"
                                color: ThemeBackend.text
                                font.family: "sans-serif"
                                font.pixelSize: section.s(11)
                                font.bold: true
                            }
                        }
                    }
                    ColumnLayout {
                        id: cardBody
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: preview.bottom
                            margins: section.s(14)
                        }
                        spacing: section.s(8)
                        Copy {
                            Layout.fillWidth: true
                            text: card.modelData.name
                            color: ThemeBackend.text
                            font.family: "sans-serif"
                            font.pixelSize: section.s(17)
                            font.bold: true
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                        }
                        Copy {
                            Layout.fillWidth: true
                            text: card.modelData.barPosition + " bar · " + (card.modelData.dockEnabled ? card.modelData.dockPosition + " dock" : "dock hidden") + " · " + card.modelData.widgetCount + " widgets · " + IconPacks.nameFor(card.modelData.iconPack || "EvhOs-Satin") + " icons"
                            font.pixelSize: section.s(11)
                        }
                        Copy {
                            Layout.fillWidth: true
                            visible: card.modelData.missingAssets.length > 0
                            text: "Saved wallpaper unavailable — reselect it and save this theme."
                            font.pixelSize: section.s(11)
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: section.s(7)
                            PresetAction {
                                text: card.active ? "Active theme" : "Use theme…"
                                primary: !card.active
                                enabled: !DesktopPresets.busy && !card.active
                                onClicked: DesktopPresets.request("apply", card.modelData.name)
                            }
                            PresetAction {
                                text: card.moreOpen ? "Done" : "Manage"
                                enabled: !DesktopPresets.busy
                                onClicked: section.expandedTheme = card.moreOpen ? "" : card.modelData.name
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                            implicitHeight: card.moreOpen ? moreActions.implicitHeight : 0
                            visible: card.moreOpen || implicitHeight > 0.1
                            clip: true
                            opacity: card.moreOpen ? 1 : 0
                            Behavior on implicitHeight {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutCubic
                                }
                            }
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 150
                                }
                            }
                            Flow {
                                id: moreActions
                                width: parent.width
                                spacing: section.s(6)
                                enabled: !DesktopPresets.busy && !DesktopPresets.editing
                                PresetAction {
                                    text: "Rename…"
                                    onClicked: DesktopPresets.openName("rename", card.modelData.name)
                                }
                                PresetAction {
                                    text: "Make a copy…"
                                    onClicked: DesktopPresets.openName("duplicate", card.modelData.name)
                                }
                                PresetAction {
                                    text: "Remove…"
                                    destructive: true
                                    onClicked: DesktopPresets.deleteName = card.modelData.name
                                }
                            }
                        }
                    }
                }
            }
        }
        Copy {
            Layout.fillWidth: true
            text: "Changes save automatically to the active theme. Shared shell code stays installed across themes."
            font.pixelSize: section.s(11)
        }
        Copy {
            Layout.fillWidth: true
            visible: DesktopPresets.message !== "" && !DesktopPresets.hasDialog
            text: DesktopPresets.message
            color: DesktopPresets.error ? ThemeBackend.red : ThemeBackend.subtext0
        }
        Copy {
            Layout.fillWidth: true
            visible: DesktopPresets.autosaveError !== ""
            text: DesktopPresets.autosaveError
            color: ThemeBackend.red
        }
        Copy {
            Layout.fillWidth: true
            visible: DesktopPresets.state.warnings.length > 0
            text: DesktopPresets.state.warnings.join("\n")
            color: ThemeBackend.red
        }
    }
}
