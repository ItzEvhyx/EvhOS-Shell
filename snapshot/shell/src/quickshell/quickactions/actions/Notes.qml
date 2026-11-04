import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../reusables"
import "../../"
import "NotesFormat.js" as NotesFormat

Item {
    id: root

    property int requestedLayoutTemplate: 1
    property bool isActiveTab: typeof isCurrentTarget !== "undefined" ? isCurrentTarget : true
    property string nerdFont: ThemeBackend.iconFont
    property string safeActiveEdge: typeof activeEdge !== "undefined" ? activeEdge : "left"

    property bool stateLoaded: false
    property var interceptedShortcuts: isEditing ? ["Return", "Enter", "Left", "Right", "Up", "Down", "Escape"] : []
    readonly property bool hasInputFocus: (typeof nameInput !== "undefined" && nameInput.hasFocus) || (typeof contentInput !== "undefined" && contentInput.hasFocus)

    function unfocusInputs() {
        if (typeof nameInput !== "undefined" && typeof nameInput.releaseFocus === "function") {
            nameInput.releaseFocus();
        }
        if (typeof contentInput !== "undefined" && typeof contentInput.releaseFocus === "function") {
            contentInput.releaseFocus();
        }
    }

    Shortcut {
        enabled: root.isActiveTab && root.isEditing
        sequence: "Escape"
        onActivated: root.saveCurrentNote()
    }

    function s(val) {
        return typeof scaleFunc === "function" ? scaleFunc(val) : val;
    }

    property real baseW: s(460)
    property real baseL: s(430)

    property real preferredWidth: (root.safeActiveEdge === "bottom" || root.safeActiveEdge === "top") ? baseL + 50 : baseW
    property real preferredExtraLength: (root.safeActiveEdge === "bottom" || root.safeActiveEdge === "top") ? baseW : baseL

    property real counterRotation: {
        if (root.safeActiveEdge === "right") return 180;
        if (root.safeActiveEdge === "bottom") return 90;
        if (root.safeActiveEdge === "top") return -90;
        return 0;
    }

    function alpha(color, a) { return Qt.rgba(color.r, color.g, color.b, a); }

    function getStorageDir() {
        return (typeof Caching !== "undefined" && Caching.stateDir ? Caching.stateDir : ((Quickshell.env("HOME") || "") + "/.local/state/serpantinum")) + "/quickactions";
    }

    property var notesList: []
    property var selectedIds: ({})
    property int selectedCount: 0

    property bool isEditing: false
    property string editingNoteId: ""
    property real editingUpdatedAt: 0
    property bool editingNotePinned: false
    property bool isMarkdownPreview: false
    property bool editorLoading: false
    property bool editorDirty: false
    property var editHistory: []
    property int historyIndex: -1
    property bool restoringHistory: false

    Timer { id: historyTimer; interval: 400; onTriggered: root.recordHistory() }
    function resetHistory() {
        historyTimer.stop();
        editHistory = [contentInput.text];
        historyIndex = 0;
    }
    function recordHistory() {
        historyTimer.stop();
        if (!isEditing || editorLoading || restoringHistory) return;
        let text = contentInput.text;
        if (historyIndex >= 0 && editHistory[historyIndex] === text) return;
        let history = editHistory.slice(0, historyIndex + 1);
        history.push(text);
        if (history.length > 100) history.shift();
        editHistory = history;
        historyIndex = history.length - 1;
    }
    function contentEdited() {
        if (isEditing && !editorLoading && !restoringHistory) historyTimer.restart();
        scheduleSave();
    }
    function moveHistory(direction) {
        recordHistory();
        let next = historyIndex + direction;
        if (next < 0 || next >= editHistory.length) return;
        let edit = contentInput.multilineEditor;
        let cursor = edit.cursorPosition;
        restoringHistory = true;
        historyIndex = next;
        contentInput.text = editHistory[next];
        edit.cursorPosition = Math.min(cursor, edit.length);
        restoringHistory = false;
        contentInput.forceInputFocus();
        scheduleSave();
    }

    onIsActiveTabChanged: if (!isActiveTab) flushEdits()
    Component.onDestruction: flushEdits()

    Timer { id: autosaveTimer; interval: 500; onTriggered: root.flushEdits() }
    function scheduleSave() {
        if (isEditing && !editorLoading) { editorDirty = true; autosaveTimer.restart(); }
    }
    function flushEdits() {
        autosaveTimer.stop();
        if (isEditing && editorDirty) persistCurrentNote();
    }

    readonly property bool areSelectedNotesPinned: {
        let keys = Object.keys(root.selectedIds);
        if (keys.length === 0) return false;
        for (let i = 0; i < root.notesList.length; i++) {
            let n = root.notesList[i];
            if (root.selectedIds[n.id] && !n.pinned) {
                return false;
            }
        }
        return true;
    }

    readonly property var displayNotesList: {
        let dummy = (typeof I18n !== "undefined" ? I18n.currentLang : "");
        let raw = root.notesList || [];
        let hasPinned = false;
        for (let i = 0; i < raw.length; i++) {
            if (raw[i].pinned) {
                hasPinned = true;
                break;
            }
        }
        let pinnedLabel = I18n.t("quickactions.notes.pinned");
        if (pinnedLabel === "quickactions.notes.pinned") {
            pinnedLabel = I18n.t("clipboard.pinned");
            if (pinnedLabel === "clipboard.pinned") pinnedLabel = "Pinned";
        }
        let recentLabel = I18n.t("quickactions.notes.recent");
        if (recentLabel === "quickactions.notes.recent") {
            recentLabel = I18n.t("clipboard.recent");
            if (recentLabel === "clipboard.recent") recentLabel = "Recent";
        }

        let pinned = [];
        let unpinned = [];
        for (let i = 0; i < raw.length; i++) {
            let item = raw[i];
            let copy = Object.assign({}, item);
            copy.sectionCategory = hasPinned ? (item.pinned ? pinnedLabel : recentLabel) : "";
            if (item.pinned) {
                pinned.push(copy);
            } else {
                unpinned.push(copy);
            }
        }
        return pinned.concat(unpinned);
    }

    property real expandProgress: 0.0
    property bool isDraggingV: false
    Behavior on expandProgress {
        enabled: !root.isDraggingV
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    onExpandProgressChanged: {
        if (expandProgress <= 0.001 && isEditing && !isDraggingV) {
            flushEdits();
            isEditing = false;
            editingNoteId = "";
        }
    }

    property real currentTimeTicker: 0
    Timer {
        interval: 10000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.currentTimeTicker = Date.now()
    }

    function formatRelativeTime(timestamp) {
        let fmt = (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.time && Config.rawSettings.bar.time.format !== undefined) ? Config.rawSettings.bar.time.format : "HH:mm";
        return NotesFormat.formatRelativeTime(timestamp, I18n, fmt);
    }

    function formatPreciseTime(timestamp) {
        return NotesFormat.formatPreciseTime(timestamp);
    }

    FileView {
        id: notesStore
        path: root.getStorageDir() + "/notes.json"
        blockWrites: true
        atomicWrites: true
        onSaveFailed: error => console.warn("Notes could not be saved:", error)
    }

    Process {
        id: loadNotesProc
        command: ["bash", "-c", "mkdir -p -- \"$1\"; if [ -f \"$1/notes.json\" ]; then cat -- \"$1/notes.json\"; else echo '[]'; fi", "notes", root.getStorageDir()]
        stdout: StdioCollector {
            id: loadNotesOut
            onStreamFinished: {
                root.restoreNotes(loadNotesOut.text);
            }
        }
    }

    Component.onCompleted: {
        loadNotesProc.running = true;
    }

    function restoreNotes(rawText) {
        let txt = (rawText || "").trim();
        if (txt !== "") {
            try {
                let data = JSON.parse(txt);
                if (Array.isArray(data)) {
                    root.notesList = data;
                }
            } catch (e) {}
        }
        root.stateLoaded = true;
    }

    function saveNotes() {
        if (!root.stateLoaded) return;
        notesStore.setText(JSON.stringify(root.notesList));
    }

    function isSelected(id) {
        return !!root.selectedIds[id];
    }

    function toggleSelection(id) {
        let copy = Object.assign({}, root.selectedIds);
        if (copy[id]) {
            delete copy[id];
        } else {
            copy[id] = true;
        }
        root.selectedIds = copy;
        root.selectedCount = Object.keys(copy).length;
    }

    function clearSelection() {
        root.selectedIds = ({});
        root.selectedCount = 0;
    }

    function deleteSelectedNotes() {
        let remaining = [];
        for (let i = 0; i < root.notesList.length; i++) {
            let item = root.notesList[i];
            if (!root.selectedIds[item.id]) {
                remaining.push(item);
            }
        }
        root.notesList = remaining;
        root.clearSelection();
        root.saveNotes();
    }

    function togglePinSelectedNotes() {
        let allPinned = root.areSelectedNotesPinned;
        let targetPinned = !allPinned;
        let list = root.notesList.map(n => {
            if (root.selectedIds[n.id]) {
                let copy = Object.assign({}, n);
                copy.pinned = targetPinned;
                return copy;
            }
            return n;
        });
        root.notesList = list;
        root.clearSelection();
        root.saveNotes();
    }

    function createNewNote() {
        root.clearSelection();
        let newId = "note_" + Date.now();
        root.editingNoteId = newId;
        root.editingUpdatedAt = Date.now();
        root.editingNotePinned = false;
        root.editorLoading = true;
        nameInput.text = "";
        contentInput.text = "";
        root.editorLoading = false;
        root.editorDirty = false;
        root.isMarkdownPreview = false;
        root.isEditing = true;
        root.resetHistory();
        root.expandProgress = 1.0;
    }

    function openNote(noteItem) {
        if (root.selectedCount > 0) {
            root.toggleSelection(noteItem.id);
            return;
        }
        root.editingNoteId = noteItem.id;
        root.editingUpdatedAt = noteItem.updatedAt || Date.now();
        root.editingNotePinned = Boolean(noteItem.pinned);
        root.editorLoading = true;
        nameInput.text = noteItem.title || "";
        contentInput.text = root.prepareNoteForEditor(noteItem);
        root.editorLoading = false;
        root.editorDirty = false;
        root.isMarkdownPreview = false;
        root.isEditing = true;
        root.resetHistory();
        root.expandProgress = 1.0;
    }

    function saveCurrentNote() {
        flushEdits();
        root.expandProgress = 0.0;
    }

    function persistCurrentNote() {
        if (!root.isEditing || !root.stateLoaded || !root.editingNoteId) return;
        let t = nameInput.text.trim();
        let c = contentInput.text;
        let id = root.editingNoteId;
        let list = root.notesList.slice();
        let idx = list.findIndex(n => n.id === id);
        if (t === "" && c.trim() === "" && idx === -1) {
            root.editorDirty = false;
            return;
        }
        if (t === "") {
            let firstLine = c.trim().split("\n")[0];
            t = firstLine.length > 25 ? firstLine.substring(0, 25) + "..." : firstLine;
            if (!t) t = I18n.t("quickactions.notes.new_note_title");
        }
        let now = Date.now();
        let note = Object.assign({}, idx >= 0 ? list[idx] : {}, {
            id: id, title: t, content: c, pinned: root.editingNotePinned, editorFormat: "markdown-visual-v1",
            updatedAt: now, createdAt: idx >= 0 ? (list[idx].createdAt || now) : now
        });
        if (idx >= 0) list[idx] = note; else list.unshift(note);
        root.notesList = list;
        root.saveNotes();
        root.editorDirty = false;
        root.editingUpdatedAt = now;
    }

    function prepareNoteForEditor(note) {
        let content = note.content || "";
        if (note.editorFormat === "markdown-visual-v1") return content;
        // Legacy notes treated every newline as a visible line break.
        return content.replace(/\r\n/g, "\n").split("\n").map(line =>
            line.trim() && !/^(\s*#{1,6} |\s*[-*+] |\s*\d+\. |\s*!\[)/.test(line) ? line + "  " : line
        ).join("\n");
    }

    // Qt serializes each selected fragment as a complete Markdown paragraph.
    function markdownFragment(edit, start, end) {
        if (start >= end) return "";
        let result = edit.getFormattedText(start, end).replace(/\n+$/, "");
        let plain = edit.getText(start, end);
        return result + (/[\u2028\u2029\n]$/.test(plain) ? "\n\n" : "");
    }

    function replaceFormattedRange(edit, start, end, replacement) {
        let before = markdownFragment(edit, 0, start);
        let separator = end < edit.length && /[\u2028\u2029\n]/.test(edit.getText(end, end + 1));
        let after = markdownFragment(edit, end + (separator ? 1 : 0), edit.length);
        edit.text = before + replacement + (separator ? "\n\n" : "") + after;
    }

    function applyFormat(kind) {
        if (kind === "undo" || kind === "redo") {
            moveHistory(kind === "undo" ? -1 : 1);
            return;
        }
        recordHistory();
        let edit = contentInput.multilineEditor;
        let start = edit.selectionStart, end = edit.selectionEnd;
        let selected = markdownFragment(edit, start, end);
        let cursor = start;
        if (kind === "bold" || kind === "italic") {
            let mark = kind === "bold" ? "**" : "*";
            if (!selected) {
                selected = kind === "bold" ? "bold text" : "italic text";
            }
            let formatted = selected.startsWith(mark) && selected.endsWith(mark) && selected.length > mark.length * 2
                ? selected.substring(mark.length, selected.length - mark.length) : mark + selected + mark;
            replaceFormattedRange(edit, start, end, formatted);
            cursor = start + (end > start ? end - start : selected.length);
        } else {
            let plain = edit.getText(0, edit.length).replace(/[\u2028\u2029]/g, "\n");
            let lineStart = plain.lastIndexOf("\n", start - 1) + 1;
            let lineEnd = plain.indexOf("\n", end);
            if (lineEnd < 0) lineEnd = plain.length;
            start = lineStart; end = lineEnd;
            let body = markdownFragment(edit, start, end).replace(/^(#{1,3} |[-*+] )/, "");
            let prefix = kind === "bullet" ? "- " : "#".repeat(Number(kind)) + " ";
            replaceFormattedRange(edit, start, end, prefix + body);
            cursor = start + (end - start);
        }
        edit.cursorPosition = Math.min(cursor, edit.length);
        if (kind === "bold" || kind === "italic") edit.select(start, edit.cursorPosition);
        contentInput.forceInputFocus();
        root.recordHistory();
        root.scheduleSave();
    }

    function pasteIntoNote() {
        if (pasteProc.running) return;
        pasteProc.noteId = root.editingNoteId;
        pasteProc.position = contentInput.multilineEditor.selectionStart;
        pasteProc.endPosition = contentInput.multilineEditor.selectionEnd;
        pasteProc.originalText = contentInput.text;
        pasteProc.command = ["python3", Caching.serpantinumDir + "/scripts/notes_paste_image.py", root.getStorageDir()];
        pasteProc.running = true;
    }
    Process {
        id: pasteProc
        property string noteId: ""
        property int position: 0
        property int endPosition: 0
        property string originalText: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.isEditing || pasteProc.noteId !== root.editingNoteId) return;
                let result = text.trim();
                let edit = contentInput.multilineEditor;
                if (result.startsWith("IMAGE:")) {
                    let position = Math.min(pasteProc.position, edit.length);
                    if (contentInput.text !== pasteProc.originalText) position = edit.cursorPosition;
                    else if (pasteProc.endPosition > position) edit.remove(position, pasteProc.endPosition);
                    let plainBefore = edit.getText(0, position);
                    let plainAfter = edit.getText(position, edit.length);
                    let imageText = (plainBefore && !/[\u2029\n]$/.test(plainBefore) ? "\n\n" : "") +
                                    "![Image](" + result.substring(6) + ")" +
                                    (plainAfter && !/^[\u2029\n]/.test(plainAfter) ? "\n\n" : "");
                    root.replaceFormattedRange(edit, position, position, imageText);
                    edit.cursorPosition = Math.min(position + 2, edit.length);
                    root.scheduleSave();
                } else if (result === "TEXT") {
                    edit.paste();
                } else {
                    console.warn("Could not paste image into note:", result);
                }
            }
        }
    }

    function markdownToHtml(md) {
        return NotesFormat.markdownToHtml(md);
    }

    Item {
        id: orientedRoot
        anchors.centerIn: parent
        width: (root.counterRotation % 180 !== 0) ? parent.height : parent.width
        height: (root.counterRotation % 180 !== 0) ? parent.width : parent.height
        rotation: root.counterRotation
        clip: true

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            radius: ThemeBackend.borderRadius

            Item {
                id: mainListView
                anchors.fill: parent
                opacity: Math.max(0.0, 1.0 - root.expandProgress * 1.5)
                visible: opacity > 0.001

                Item {
                    id: listControlBar
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: root.s(42)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: root.s(10)
                        anchors.rightMargin: root.s(10)
                        spacing: root.s(8)

                        ClickButton {
                            visible: root.selectedCount === 0
                            Layout.fillWidth: true
                            buttonText: I18n.t("quickactions.notes.add_note")
                            buttonIcon: "󰐕"
                            iconFont: root.nerdFont
                            iconFontSize: root.s(14)
                            textFontSize: root.s(12)
                            accentColor: ThemeBackend.surface0
                            bgOpacity: ThemeBackend.elementOpacity
                            textColor: ThemeBackend.text
                            cornerRadius: root.s(10)
                            implicitHeight: root.s(32)
                            onClicked: root.createNewNote()
                        }

                        Text {
                            visible: root.selectedCount > 0
                            text: {
                                let t = I18n.t("quickactions.notes.selected_count", { count: root.selectedCount });
                                return (t !== "quickactions.notes.selected_count") ? t : (root.selectedCount + " selected");
                            }
                            color: ThemeBackend.mauve
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(13)
                            font.bold: true
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            Layout.alignment: Qt.AlignVCenter
                        }

                        IconButton {
                            visible: root.selectedCount > 0
                            size: root.s(32)
                            cornerRadius: root.s(8)
                            iconFont: root.nerdFont
                            iconFontSize: root.s(15)
                            buttonIcon: "󰐃"
                            textColor: root.areSelectedNotesPinned ? ThemeBackend.mauve : ThemeBackend.subtext0
                            accentColor: root.areSelectedNotesPinned ? root.alpha(ThemeBackend.mauve, 0.2) : ThemeBackend.surface0
                            bgOpacity: ThemeBackend.elementOpacity
                            Layout.alignment: Qt.AlignVCenter
                            onClicked: root.togglePinSelectedNotes()
                        }

                        CloseButton {
                            visible: root.selectedCount > 0
                            size: root.s(32)
                            cornerRadius: root.s(8)
                            iconFont: root.nerdFont
                            iconFontSize: root.s(15)
                            textColor: ThemeBackend.subtext0
                            accentColor: ThemeBackend.surface0
                            bgOpacity: ThemeBackend.elementOpacity
                            Layout.alignment: Qt.AlignVCenter
                            onClicked: root.clearSelection()
                        }

                        IconButton {
                            visible: root.selectedCount > 0
                            size: root.s(32)
                            cornerRadius: root.s(8)
                            iconFont: root.nerdFont
                            iconFontSize: root.s(15)
                            buttonIcon: "󰆴"
                            textColor: ThemeBackend.red
                            accentColor: root.alpha(ThemeBackend.red, 0.18)
                            bgOpacity: ThemeBackend.elementOpacity
                            Layout.alignment: Qt.AlignVCenter
                            onClicked: root.deleteSelectedNotes()
                        }
                    }
                }

                ListView {
                    id: notesListView
                    anchors.top: listControlBar.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.topMargin: root.s(4)
                    anchors.bottomMargin: root.s(6)
                    anchors.leftMargin: root.s(8)
                    anchors.rightMargin: root.s(8)
                    spacing: root.s(6)
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.displayNotesList

                    section.property: "sectionCategory"
                    section.criteria: ViewSection.FullString
                    section.delegate: Item {
                        width: ListView.view ? ListView.view.width : 0
                        height: (section && section !== "") ? root.s(22) : 0
                        visible: section && section !== ""

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: root.s(4)
                            anchors.verticalCenter: parent.verticalCenter
                            text: section
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: root.s(10.5)
                            color: ThemeBackend.subtext0
                            opacity: 0.85
                        }
                    }

                    ScrollBar.vertical: ScrollBar {
                        active: notesListView.moving || notesListView.movingVertically
                        width: root.s(4)
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle {
                            implicitWidth: root.s(4)
                            radius: root.s(2)
                            color: ThemeBackend.surface2
                        }
                    }

                    delegate: Item {
                        id: noteDelegateWrapper
                        width: notesListView.width

                        readonly property bool isSelected: root && modelData ? root.isSelected(modelData.id) : false
                        readonly property bool isTargetNote: root.editingNoteId === modelData.id
                        property real relativeUpdateTracker: root.currentTimeTicker

                        height: isTargetNote ? (root.s(54) + (root.s(130) - root.s(54)) * root.expandProgress) : root.s(54)

                        scale: itemMouseArea.pressed ? 0.98 : 1.0
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                        Rectangle {
                            id: noteItemCard
                            anchors.fill: parent
                            radius: ThemeBackend.borderRadius
                            readonly property color legacyColor: {
                                if (noteDelegateWrapper.isSelected) {
                                    return ThemeBackend.mauve;
                                }
                                return Qt.alpha(itemMouseArea.containsMouse ? Qt.lighter(ThemeBackend.surface1, 1.04) : ThemeBackend.surface1, ThemeBackend.elementOpacity);
                            }
                            color: noteGlass.active ? "transparent" : legacyColor
                            clip: true

                            GlassFill {
                                id: noteGlass
                                anchors.fill: parent
                                radius: parent.radius
                                tintColor: noteDelegateWrapper.isSelected ? ThemeBackend.mauve : ThemeBackend.surface1
                                tintAmount: noteDelegateWrapper.isSelected ? 0.5 : 0.3
                                press: itemMouseArea.pressed ? 0.8 : (itemMouseArea.containsMouse ? 0.2 : 0)
                                Behavior on press { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                            }

                            Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: root.s(12)
                                anchors.rightMargin: root.s(12)
                                spacing: root.s(10)

                                Item {
                                    id: noteIconArea
                                    Layout.preferredWidth: root.s(30)
                                    Layout.preferredHeight: root.s(30)
                                    Layout.alignment: Qt.AlignVCenter

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: root.s(8)
                                        color: noteDelegateWrapper.isSelected
                                            ? Qt.rgba(0, 0, 0, 0.15)
                                            : Qt.alpha(ThemeBackend.surface2, ThemeBackend.elementOpacity)

                                        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }

                                        Text {
                                            anchors.centerIn: parent
                                            font.family: root.nerdFont
                                            font.pixelSize: root.s(14)
                                            color: (noteDelegateWrapper.isSelected && !noteGlass.active) ? ThemeBackend.crust : (noteDelegateWrapper.isSelected ? ThemeBackend.text : ThemeBackend.subtext0)
                                            text: "󰈙"

                                            Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: root.s(1)

                                    Text {
                                        text: modelData.title || I18n.t("quickactions.notes.new_note_title")
                                        color: (noteDelegateWrapper.isSelected && !noteGlass.active) ? ThemeBackend.crust : ThemeBackend.text
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: root.s(12)
                                        font.weight: noteDelegateWrapper.isSelected ? Font.Bold : Font.Medium
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight

                                        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                    }

                                    Text {
                                        text: {
                                            let c = (modelData.content || "").replace(/\n/g, " ").trim();
                                            return c.length > 0 ? c : "...";
                                        }
                                        color: (noteDelegateWrapper.isSelected && !noteGlass.active) ? ThemeBackend.crust : (noteDelegateWrapper.isSelected ? ThemeBackend.text : ThemeBackend.subtext0)
                                        opacity: noteDelegateWrapper.isSelected ? 0.9 : 0.85
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: root.s(10)
                                        font.weight: Font.Normal
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight

                                        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                    }
                                }

                                RowLayout {
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: root.s(6)

                                    Text {
                                        text: root.formatRelativeTime(modelData.updatedAt)
                                        color: (noteDelegateWrapper.isSelected && !noteGlass.active) ? ThemeBackend.crust : (noteDelegateWrapper.isSelected ? ThemeBackend.text : ThemeBackend.subtext1)
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: root.s(10)

                                        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                    }

                                    FlipIcon {
                                        id: noteExpandBtn
                                        size: root.s(26)
                                        cornerRadius: root.s(6)
                                        accentColor: ThemeBackend.surface2
                                        bgOpacity: ThemeBackend.elementOpacity
                                        iconColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.subtext1
                                        autoToggle: false
                                        flipped: isTargetNote && root.expandProgress > 0.5
                                        visible: root.selectedCount === 0
                                        onClicked: root.openNote(modelData)
                                    }
                                }
                            }

                            MouseArea {
                                id: itemMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton

                                property real startY: 0
                                property bool draggingV: false

                                onPressed: mouse => {
                                    startY = mouse.y;
                                    draggingV = false;
                                    root.isDraggingV = false;
                                }

                                onPositionChanged: mouse => {
                                    if (!pressed) return;
                                    let dy = mouse.y - startY;
                                    if (!draggingV && dy > root.s(6)) {
                                        if (root.selectedCount === 0) {
                                            draggingV = true;
                                            root.isDraggingV = true;
                                            preventStealing = true;
                                            root.editingNoteId = modelData.id;
                                            root.editingUpdatedAt = modelData.updatedAt || Date.now();
                                            root.editingNotePinned = Boolean(modelData.pinned);
                                            root.editorLoading = true;
                                            nameInput.text = modelData.title || "";
                                            contentInput.text = root.prepareNoteForEditor(modelData);
                                            root.editorLoading = false;
                                            root.editorDirty = false;
                                            root.isMarkdownPreview = false;
                                            root.isEditing = true;
                                            root.resetHistory();
                                        }
                                    }

                                    if (draggingV) {
                                        let prog = Math.max(0.0, Math.min(1.0, dy / root.s(90)));
                                        root.expandProgress = prog;
                                    }
                                }

                                onReleased: mouse => {
                                    preventStealing = false;
                                    if (draggingV) {
                                        root.isDraggingV = false;
                                        draggingV = false;
                                        if (root.expandProgress > 0.35) {
                                            root.expandProgress = 1.0;
                                        } else {
                                            root.expandProgress = 0.0;
                                        }
                                    } else {
                                        if (mouse.button === Qt.RightButton) {
                                            root.toggleSelection(modelData.id);
                                        } else {
                                            root.openNote(modelData);
                                        }
                                    }
                                }

                                onCanceled: {
                                    preventStealing = false;
                                    if (draggingV) {
                                        root.isDraggingV = false;
                                        draggingV = false;
                                        if (root.expandProgress > 0.35) {
                                            root.expandProgress = 1.0;
                                        } else {
                                            root.expandProgress = 0.0;
                                        }
                                    }
                                }

                                onPressAndHold: {
                                    if (!draggingV) {
                                        root.toggleSelection(modelData.id);
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    anchors.centerIn: parent
                    visible: root.notesList.length === 0
                    width: parent.width - root.s(40)
                    height: emptyCol.implicitHeight

                    ColumnLayout {
                        id: emptyCol
                        anchors.centerIn: parent
                        spacing: root.s(10)

                        Text {
                            text: "󰈙"
                            font.family: root.nerdFont
                            font.pixelSize: root.s(36)
                            color: ThemeBackend.surface2
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: I18n.t("quickactions.notes.no_notes")
                            color: ThemeBackend.subtext0
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(12)
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }

            Item {
                id: editorView
                anchors.fill: parent
                visible: root.expandProgress > 0.001
                opacity: Math.max(0.0, (root.expandProgress - 0.15) / 0.85)
                scale: 0.96 + 0.04 * root.expandProgress
                transform: Translate { y: root.s(25) * (1.0 - root.expandProgress) }

                Rectangle {
                    id: editorCard
                    anchors.fill: parent
                    anchors.margins: root.s(8)
                    color: editorGlass.active ? "transparent" : Qt.alpha(ThemeBackend.surface1, ThemeBackend.elementOpacity)
                    radius: ThemeBackend.borderRadius
                    clip: true

                    GlassFill {
                        id: editorGlass
                        anchors.fill: parent
                        radius: parent.radius
                        tintColor: ThemeBackend.surface1
                        tintAmount: 0.3
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: root.s(8)
                        spacing: root.s(8)

                        Item {
                            id: editorHeaderBar
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.s(32)

                            RowLayout {
                                anchors.fill: parent
                                spacing: root.s(8)

                                CloseButton {
                                    id: closeBtn
                                    size: root.s(32)
                                    cornerRadius: root.s(8)
                                    iconFont: root.nerdFont
                                    iconFontSize: root.s(15)
                                    textColor: ThemeBackend.text
                                    accentColor: ThemeBackend.surface2
                                    bgOpacity: ThemeBackend.elementOpacity
                                    Layout.alignment: Qt.AlignVCenter
                                    onClicked: root.saveCurrentNote()
                                }

                                Item {
                                    id: headerTitleArea
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    ColumnLayout {
                                        id: headerTitleCol
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 0

                                        Text {
                                            text: root.isMarkdownPreview ? I18n.t("quickactions.notes.preview_note") : I18n.t("quickactions.notes.edit_note")
                                            color: ThemeBackend.text
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: root.s(12.5)
                                            font.bold: true
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            text: root.formatPreciseTime(root.editingUpdatedAt)
                                            color: ThemeBackend.subtext0
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: root.s(9.5)
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        id: headerDragArea
                                        anchors.fill: parent
                                        hoverEnabled: true

                                        property real startY: 0
                                        property bool draggingV: false

                                        onPressed: mouse => {
                                            startY = mouse.y;
                                            draggingV = false;
                                            root.isDraggingV = false;
                                        }

                                        onPositionChanged: mouse => {
                                            if (!pressed) return;
                                            let dy = mouse.y - startY;
                                            if (!draggingV && dy > root.s(6)) {
                                                draggingV = true;
                                                root.isDraggingV = true;
                                                preventStealing = true;
                                            }
                                            if (draggingV) {
                                                let prog = Math.max(0.0, Math.min(1.0, 1.0 - (dy / root.s(90))));
                                                root.expandProgress = prog;
                                            }
                                        }

                                        onReleased: {
                                            preventStealing = false;
                                            if (draggingV) {
                                                root.isDraggingV = false;
                                                draggingV = false;
                                                if (root.expandProgress < 0.65) {
                                                    root.saveCurrentNote();
                                                } else {
                                                    root.expandProgress = 1.0;
                                                }
                                            }
                                        }

                                        onCanceled: {
                                            preventStealing = false;
                                            if (draggingV) {
                                                root.isDraggingV = false;
                                                draggingV = false;
                                                if (root.expandProgress < 0.65) {
                                                    root.saveCurrentNote();
                                                } else {
                                                    root.expandProgress = 1.0;
                                                }
                                            }
                                        }
                                    }
                                }

                                IconButton {
                                    id: pinBtn
                                    size: root.s(32)
                                    cornerRadius: root.s(8)
                                    iconFont: root.nerdFont
                                    iconFontSize: root.s(15)
                                    buttonIcon: "󰐃"
                                    textColor: root.editingNotePinned ? ThemeBackend.mauve : ThemeBackend.subtext0
                                    accentColor: root.editingNotePinned ? root.alpha(ThemeBackend.mauve, 0.2) : ThemeBackend.surface2
                                    bgOpacity: ThemeBackend.elementOpacity
                                    Layout.alignment: Qt.AlignVCenter
                                    onClicked: { root.editingNotePinned = !root.editingNotePinned; root.scheduleSave(); }
                                }

                                IconButton {
                                    id: markdownPreviewBtn
                                    size: root.s(32)
                                    cornerRadius: root.s(8)
                                    iconFont: root.nerdFont
                                    iconFontSize: root.s(15)
                                    buttonIcon: root.isMarkdownPreview ? "󰈙" : "󰂺"
                                    textColor: root.isMarkdownPreview ? ThemeBackend.mauve : ThemeBackend.subtext0
                                    accentColor: root.isMarkdownPreview ? root.alpha(ThemeBackend.mauve, 0.2) : ThemeBackend.surface2
                                    bgOpacity: ThemeBackend.elementOpacity
                                    Layout.alignment: Qt.AlignVCenter
                                    onClicked: root.isMarkdownPreview = !root.isMarkdownPreview
                                }

                                ClickButton {
                                    id: saveBtn
                                    buttonText: I18n.t("quickactions.notes.save")
                                    buttonIcon: "󰄬"
                                    iconFont: root.nerdFont
                                    iconFontSize: root.s(13)
                                    textFontSize: root.s(12)
                                    accentColor: ThemeBackend.mauve
                                    bgOpacity: ThemeBackend.elementOpacity
                                    textColor: ThemeBackend.base
                                    cornerRadius: root.s(8)
                                    implicitHeight: root.s(32)
                                    Layout.alignment: Qt.AlignVCenter
                                    onClicked: root.saveCurrentNote()
                                }
                            }
                        }

                        Item {
                            id: noteNameWrapper
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.s(34)

                            Input {
                                id: nameInput
                                anchors.fill: parent
                                baseColor: ThemeBackend.surface0
                                bgOpacity: ThemeBackend.elementOpacity
                                textColor: ThemeBackend.text
                                placeholderText: I18n.t("quickactions.notes.title_placeholder")
                                cornerRadius: root.s(8)
                                fontPixelSize: root.s(12)
                                leadingIcon: ""
                                showClearButton: true
                                onTextEdited: root.scheduleSave()
                                onCleared: root.scheduleSave()
                                visible: !root.isMarkdownPreview
                            }

                            Rectangle {
                                id: previewTitleBar
                                anchors.fill: parent
                                radius: root.s(8)
                                color: Qt.alpha(ThemeBackend.surface0, ThemeBackend.elementOpacity)
                                visible: root.isMarkdownPreview

                                Text {
                                    anchors.fill: parent
                                    anchors.leftMargin: root.s(12)
                                    anchors.rightMargin: root.s(12)
                                    verticalAlignment: Text.AlignVCenter
                                    text: nameInput.text.trim().length > 0 ? nameInput.text.trim() : I18n.t("quickactions.notes.new_note_title")
                                    color: ThemeBackend.text
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: root.s(12.5)
                                    font.bold: true
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: root.s(4)
                            visible: !root.isMarkdownPreview
                            Repeater {
                                model: [
                                    { label: "B", kind: "bold", tip: "Bold" },
                                    { label: "I", kind: "italic", tip: "Italic" },
                                    { label: "H1", kind: "1", tip: "Large heading" },
                                    { label: "H2", kind: "2", tip: "Medium heading" },
                                    { label: "H3", kind: "3", tip: "Small heading" },
                                    { label: "•", kind: "bullet", tip: "Bullet list" }
                                ]
                                delegate: Button {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: root.s(30)
                                    text: modelData.label
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: root.s(11)
                                    font.bold: modelData.kind === "bold"
                                    font.italic: modelData.kind === "italic"
                                    ToolTip.visible: hovered
                                    ToolTip.text: modelData.tip
                                    background: Rectangle {
                                        radius: root.s(7)
                                        color: parent.down ? ThemeBackend.surface2 : (parent.hovered ? ThemeBackend.surface1 : ThemeBackend.surface0)
                                    }
                                    contentItem: Text {
                                        text: parent.text
                                        font: parent.font
                                        color: ThemeBackend.text
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    onClicked: root.applyFormat(modelData.kind)
                                }
                            }
                        }

                        Item {
                            id: editorContent
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            TapHandler {
                                enabled: !root.isMarkdownPreview
                                onPressedChanged: {
                                    if (pressed) {
                                        contentInput.forceInputFocus();
                                    }
                                }
                                onTapped: {
                                    contentInput.forceInputFocus();
                                }
                            }

                            Input {
                                id: contentInput
                                anchors.fill: parent
                                baseColor: ThemeBackend.surface0
                                bgOpacity: ThemeBackend.elementOpacity
                                textColor: ThemeBackend.text
                                placeholderText: I18n.t("quickactions.notes.content_placeholder")
                                cornerRadius: root.s(8)
                                fontPixelSize: root.s(12)
                                multiLine: true
                                markdownMode: true
                                interceptFormatting: true
                                onFormatRequested: kind => root.applyFormat(kind)
                                interceptPaste: true
                                onPasteRequested: root.pasteIntoNote()
                                onTextEdited: root.contentEdited()
                                leadingIcon: ""
                                visible: !root.isMarkdownPreview
                            }

                            Rectangle {
                                id: previewContainer
                                anchors.fill: parent
                                color: Qt.alpha(ThemeBackend.surface0, ThemeBackend.elementOpacity)
                                radius: root.s(8)
                                visible: root.isMarkdownPreview

                                Flickable {
                                    id: previewFlickable
                                    anchors.fill: parent
                                    anchors.margins: root.s(10)
                                    contentWidth: width
                                    contentHeight: previewText.height
                                    boundsBehavior: Flickable.StopAtBounds
                                    clip: true

                                    ScrollBar.vertical: ScrollBar {
                                        active: previewFlickable.moving || previewFlickable.movingVertically
                                        width: root.s(4)
                                        policy: ScrollBar.AsNeeded
                                        contentItem: Rectangle {
                                            implicitWidth: root.s(4)
                                            radius: root.s(2)
                                            color: ThemeBackend.surface2
                                        }
                                    }

                                    Text {
                                        id: previewText
                                        width: previewFlickable.width
                                        visible: root.isMarkdownPreview
                                        textFormat: Text.RichText
                                        text: root.markdownToHtml(contentInput.text)
                                        color: ThemeBackend.text
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: root.s(12)
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
