import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../"

Rectangle {
    id: root
    signal navigate(string tab)
    signal arrange
    property bool desktop: false
    property bool widgetEditor: false
    readonly property var session: DesktopPresets.session
    readonly property bool hasDialog: DesktopPresets.hasDialog
    readonly property bool presented: DesktopPresets.editing || hasDialog
    property real maxContentHeight: 10000
    property var view: ({
            nameRequested: false,
            nameAction: "save",
            nameSource: "",
            saveConfirmName: "",
            deleteName: "",
            discardConfirm: false,
            reviewData: null,
            reviewLoading: false,
            session: null
        })
    readonly property bool reviewVisible: !!view.reviewData && !view.nameRequested && !view.saveConfirmName && !view.deleteName
    function syncView() {
        if (!presented)
            return;
        let previousName = view.nameRequested ? view.nameAction + "/" + view.nameSource : "";
        let review = DesktopPresets.reviewData;
        view = {
            nameRequested: DesktopPresets.nameRequested,
            nameAction: DesktopPresets.nameAction,
            nameSource: DesktopPresets.nameSource,
            saveConfirmName: DesktopPresets.saveConfirmName,
            deleteName: DesktopPresets.deleteName,
            discardConfirm: DesktopPresets.discardConfirm,
            reviewData: review,
            reviewLoading: DesktopPresets.reviewLoading,
            session: DesktopPresets.session,
            preview: review ? ((DesktopPresets.state.presets || []).find(p => p.name === review.name) || {}).preview || "" : ""
        };
        let nextName = view.nameRequested ? view.nameAction + "/" + view.nameSource : "";
        if (nextName && previousName !== nextName) {
            nameField.text = view.nameAction === "rename" ? view.nameSource : view.nameAction === "duplicate" ? view.nameSource + " copy" : "";
            Qt.callLater(() => nameField.forceActiveFocus());
        }
    }
    onPresentedChanged: {
        if (presented) {
            syncView();
            if (view.nameRequested) {
                nameField.text = view.nameAction === "rename" ? view.nameSource : view.nameAction === "duplicate" ? view.nameSource + " copy" : "";
                Qt.callLater(() => nameField.forceActiveFocus());
            }
            Qt.callLater(() => {
                if (!view.nameRequested)
                    forceActiveFocus();
            });
        }
    }
    Component.onCompleted: syncView()
    Connections {
        target: DesktopPresets
        function onNameRequestedChanged() {
            root.syncView();
        }
        function onNameActionChanged() {
            root.syncView();
        }
        function onNameSourceChanged() {
            root.syncView();
        }
        function onSaveConfirmNameChanged() {
            root.syncView();
        }
        function onDeleteNameChanged() {
            root.syncView();
        }
        function onDiscardConfirmChanged() {
            root.syncView();
        }
        function onReviewDataChanged() {
            root.syncView();
        }
        function onReviewLoadingChanged() {
            root.syncView();
        }
        function onSessionChanged() {
            root.syncView();
        }
    }
    visible: presented || opacity > 0.001
    enabled: presented
    opacity: presented ? 1 : 0
    scale: presented ? 1 : 0.975
    transform: Translate {
        y: root.presented ? 0 : root.s(10)
        Behavior on y {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }
    implicitHeight: Math.min(contents.implicitHeight + s(48), maxContentHeight)
    Behavior on implicitHeight {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }
    color: Qt.alpha(ThemeBackend.mantle, 0.98)
    radius: s(20)
    focus: presented
    Keys.onEscapePressed: event => {
        if (root.hasDialog) {
            DesktopPresets.dismissDialog();
            event.accepted = true;
        }
    }
    border.width: 1
    border.color: Qt.alpha(ThemeBackend.text, 0.2)
    function s(value) {
        return Math.round(Scaler.s(value));
    }

    component Copy: Text {
        font.family: "sans-serif"
        font.pixelSize: root.s(13)
        color: ThemeBackend.subtext0
        wrapMode: Text.Wrap
    }
    component Choice: CheckBox {
        id: choice
        property string detail: ""
        implicitWidth: 0
        hoverEnabled: true
        implicitHeight: root.s(62)
        leftPadding: root.s(40)
        rightPadding: root.s(12)
        padding: root.s(10)
        background: Rectangle {
            radius: root.s(11)
            color: Qt.alpha(ThemeBackend.text, choice.hovered ? 0.09 : choice.checked ? 0.055 : 0.015)
            border.width: 1
            border.color: Qt.alpha(ThemeBackend.text, choice.activeFocus ? 0.6 : choice.checked ? 0.23 : 0.08)
            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }
            Behavior on border.color {
                ColorAnimation {
                    duration: 150
                }
            }
        }
        indicator: Rectangle {
            x: root.s(12)
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: root.s(18)
            implicitHeight: root.s(18)
            radius: root.s(5)
            color: choice.checked ? ThemeBackend.mauve : "transparent"
            border.width: 1
            border.color: Qt.alpha(ThemeBackend.text, choice.checked ? 0.9 : 0.35)
            Behavior on color {
                ColorAnimation {
                    duration: 130
                }
            }
            Copy {
                anchors.centerIn: parent
                text: "✓"
                visible: choice.checked
                color: ThemeBackend.crust
                font.pixelSize: root.s(13)
                font.bold: true
            }
        }
        contentItem: Column {
            spacing: root.s(3)
            Copy {
                width: choice.availableWidth
                text: choice.text
                color: ThemeBackend.text
                font.pixelSize: root.s(13)
                font.bold: true
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }
            Copy {
                width: choice.availableWidth
                visible: choice.detail !== ""
                text: choice.detail
                font.pixelSize: root.s(11)
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }
        }
        ToolTip.visible: hovered && detail !== ""
        ToolTip.delay: 650
        ToolTip.text: detail
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
    }
    Flickable {
        id: cardScroll
        objectName: "presetCardScroll"
        anchors.fill: parent
        anchors.margins: root.s(24)
        contentWidth: width
        contentHeight: contents.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }
        ColumnLayout {
            id: contents
            width: cardScroll.width
            spacing: root.s(14)
            RowLayout {
                Layout.fillWidth: true
                spacing: root.s(12)
                Copy {
                    Layout.fillWidth: true
                    text: root.view.nameRequested ? (root.view.nameAction === "rename" ? "Rename theme" : root.view.nameAction === "duplicate" ? "Make a separate copy" : "New theme from this desktop") : root.view.saveConfirmName ? "Save changes to “" + root.view.saveConfirmName + "”?" : root.view.deleteName ? "Remove “" + root.view.deleteName + "”?" : root.view.discardConfirm ? "Restore the desktop from before editing?" : root.reviewVisible ? (root.view.reviewData.source === "history" ? "Restore a previous look" : "Switch to “" + root.view.reviewData.title + "”") : root.view.reviewLoading ? "Reading the saved look…" : "Editing “" + (root.view.session ? (root.view.session.name || "New look") : "") + "”"
                    color: ThemeBackend.text
                    font.pixelSize: root.s(19)
                    font.bold: true
                }
                PresetAction {
                    objectName: "closePresetDialog"
                    text: "×"
                    visible: root.hasDialog
                    enabled: !DesktopPresets.busy
                    implicitWidth: root.s(36)
                    leftPadding: 0
                    rightPadding: 0
                    font.pixelSize: root.s(22)
                    onClicked: DesktopPresets.dismissDialog()
                    ToolTip.visible: hovered
                    ToolTip.text: "Close (Esc)"
                }
            }
            Copy {
                Layout.fillWidth: true
                visible: root.view.nameRequested
                text: root.view.nameAction === "rename" ? "Only the saved name changes. Your desktop stays as it is." : root.view.nameAction === "duplicate" ? "Creates a separate saved theme. The original stays unchanged." : "Creates and activates a separate theme. Wallpaper, apps and visual changes are saved to the active theme automatically."
            }
            TextField {
                id: nameField
                objectName: "presetThemeName"
                Layout.fillWidth: true
                Layout.preferredHeight: root.s(38)
                visible: root.view.nameRequested
                enabled: !DesktopPresets.busy
                maximumLength: 64
                placeholderText: "Name your theme"
                font.family: "sans-serif"
                font.pixelSize: root.s(14)
                color: ThemeBackend.text
                placeholderTextColor: ThemeBackend.subtext0
                background: Rectangle {
                    radius: root.s(9)
                    color: ThemeBackend.surface0
                    border.width: 1
                    border.color: nameField.activeFocus ? Qt.alpha(ThemeBackend.text, 0.7) : Qt.alpha(ThemeBackend.text, 0.15)
                }
                onAccepted: if (text.trim() && !DesktopPresets.nameProblem(text))
                    DesktopPresets.submitName(text)
            }
            Copy {
                Layout.fillWidth: true
                visible: root.view.nameRequested && text !== ""
                text: DesktopPresets.nameProblem(nameField.text)
                color: ThemeBackend.red
            }
            Flow {
                Layout.fillWidth: true
                visible: root.view.nameRequested
                spacing: root.s(7)
                PresetAction {
                    text: DesktopPresets.nameAction === "rename" ? "Rename" : DesktopPresets.nameAction === "duplicate" ? "Create copy" : (DesktopPresets.afterSave ? "Create copy and switch" : "Create theme")
                    primary: true
                    enabled: !DesktopPresets.busy && nameField.text.trim() !== "" && !DesktopPresets.nameProblem(nameField.text)
                    onClicked: DesktopPresets.submitName(nameField.text)
                }
                PresetAction {
                    text: "Cancel"
                    enabled: !DesktopPresets.busy
                    onClicked: {
                        DesktopPresets.nameRequested = false;
                        DesktopPresets.afterSave = null;
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.s(108)
                visible: root.reviewVisible && !!root.view.preview && root.maxContentHeight >= root.s(520)
                radius: root.s(12)
                color: Qt.alpha(ThemeBackend.text, 0.05)
                clip: true
                Image {
                    anchors.fill: parent
                    source: root.view.preview ? "file://" + root.view.preview.split("/").map(encodeURIComponent).join("/") : ""
                    sourceSize.width: 760
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                }
            }
            Copy {
                Layout.fillWidth: true
                visible: root.reviewVisible
                text: "Restores this theme’s saved wallpaper, apps and visuals. The theme you are leaving is saved first."
            }
            GridLayout {
                Layout.fillWidth: true
                visible: root.reviewVisible
                columns: width >= root.s(520) ? 2 : 1
                columnSpacing: root.s(10)
                rowSpacing: root.s(8)
                Repeater {
                    model: root.reviewVisible ? root.view.reviewData.components : []
                    delegate: Choice {
                        required property var modelData
                        objectName: "presetComponent_" + modelData.key
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: modelData.label
                        detail: modelData.before === modelData.after ? modelData.after : modelData.before + " → " + modelData.after
                        checked: DesktopPresets.reviewSelection.includes(modelData.key)
                        enabled: !DesktopPresets.busy
                        opacity: enabled ? 1 : 0.6
                        onClicked: DesktopPresets.setComponent(modelData.key, checked)
                    }
                }
            }
            Copy {
                Layout.fillWidth: true
                visible: root.reviewVisible && root.view.reviewData.missingAssets.length > 0
                text: "The saved wallpaper is missing. Reselect it and save the theme, or deselect Wallpaper for a layout-only restore."
                color: ThemeBackend.text
            }
            Copy {
                Layout.fillWidth: true
                visible: root.reviewVisible && DesktopPresets.state.modified
                text: "Your latest changes are saved to the active theme before switching. History keeps its earlier saved versions."
            }
            Flow {
                Layout.fillWidth: true
                visible: root.reviewVisible
                spacing: root.s(7)
                PresetAction {
                    objectName: "confirmPresetSwitch"
                    text: DesktopPresets.busy ? "Switching…" : (root.reviewVisible && root.view.reviewData.source === "history" ? "Restore look" : "Switch theme")
                    primary: true
                    enabled: !DesktopPresets.busy && DesktopPresets.reviewSelection.length > 0 && !(root.reviewVisible && DesktopPresets.reviewSelection.includes("wallpaper") && root.view.reviewData.missingAssets.length > 0)
                    onClicked: DesktopPresets.confirmSwitch()
                }
                PresetAction {
                    text: "Save a copy first…"
                    enabled: !DesktopPresets.busy && DesktopPresets.reviewSelection.length > 0
                    onClicked: DesktopPresets.saveCopyBeforeSwitch()
                }
                PresetAction {
                    text: "Cancel"
                    enabled: !DesktopPresets.busy
                    onClicked: DesktopPresets.cancelReview()
                }
            }

            Copy {
                Layout.fillWidth: true
                visible: root.view.saveConfirmName !== "" && !root.view.nameRequested
                text: "This updates only the named saved theme to match your current desktop. Its previous saved version stays in History."
            }
            Copy {
                Layout.fillWidth: true
                visible: root.view.saveConfirmName !== "" && !root.view.nameRequested
                text: "Changed: " + (DesktopPresets.changedText() || "Current appearance and layout")
                color: ThemeBackend.text
            }
            Flow {
                Layout.fillWidth: true
                visible: root.view.saveConfirmName !== "" && !root.view.nameRequested
                spacing: root.s(7)
                PresetAction {
                    text: "Save changes"
                    primary: true
                    enabled: !DesktopPresets.busy
                    onClicked: DesktopPresets.confirmUpdate()
                }
                PresetAction {
                    text: "Save as a new theme…"
                    enabled: !DesktopPresets.busy
                    onClicked: DesktopPresets.openName("save", "")
                }
                PresetAction {
                    text: "Cancel"
                    enabled: !DesktopPresets.busy
                    onClicked: DesktopPresets.saveConfirmName = ""
                }
            }
            Copy {
                Layout.fillWidth: true
                visible: root.view.deleteName !== ""
                text: "Your desktop stays unchanged. A copy of this saved look remains in History."
            }
            Flow {
                Layout.fillWidth: true
                visible: root.view.deleteName !== ""
                spacing: root.s(7)
                PresetAction {
                    text: "Remove saved theme"
                    destructive: true
                    enabled: !DesktopPresets.busy
                    onClicked: DesktopPresets.perform("delete", DesktopPresets.deleteName)
                }
                PresetAction {
                    text: "Cancel"
                    enabled: !DesktopPresets.busy
                    onClicked: DesktopPresets.deleteName = ""
                }
            }
            Copy {
                Layout.fillWidth: true
                visible: root.view.discardConfirm
                text: "The current desktop will be kept in History before the earlier layout is restored."
            }
            Flow {
                Layout.fillWidth: true
                visible: root.view.discardConfirm
                spacing: root.s(7)
                PresetAction {
                    text: "Restore earlier desktop"
                    primary: true
                    enabled: !DesktopPresets.busy
                    onClicked: DesktopPresets.perform("discard", "")
                }
                PresetAction {
                    text: "Keep editing"
                    enabled: !DesktopPresets.busy
                    onClicked: DesktopPresets.discardConfirm = false
                }
            }
            Copy {
                Layout.fillWidth: true
                visible: !!root.view.session && !root.hasDialog
                text: root.view.session && root.view.session.dirty ? "Unsaved: " + root.view.session.changedSections.map(DesktopPresets.componentLabel).join(" · ") : "Your saved theme changes only when you save."
            }
            Flow {
                Layout.fillWidth: true
                visible: !!root.view.session && !root.hasDialog
                spacing: root.s(7)
                PresetAction {
                    text: "Save changes…"
                    primary: true
                    enabled: !DesktopPresets.busy
                    onClicked: DesktopPresets.save()
                }
                PresetAction {
                    text: "Save a copy…"
                    enabled: !DesktopPresets.busy
                    onClicked: DesktopPresets.openName("save", "")
                }
                PresetAction {
                    text: "Finish editing"
                    enabled: !DesktopPresets.busy
                    onClicked: DesktopPresets.perform("finish", "")
                }
                PresetAction {
                    text: "Restore before editing…"
                    enabled: !DesktopPresets.busy
                    onClicked: DesktopPresets.request("discard", "")
                }
                PresetAction {
                    text: "Arrange widgets"
                    visible: !root.widgetEditor
                    enabled: !DesktopPresets.busy
                    onClicked: root.arrange()
                }
            }
            Copy {
                Layout.fillWidth: true
                visible: DesktopPresets.message !== "" && root.hasDialog
                text: DesktopPresets.message
                color: DesktopPresets.error ? ThemeBackend.red : ThemeBackend.subtext0
            }
        }
    }
}
