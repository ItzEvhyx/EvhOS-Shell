import QtQuick
import QtQuick.Controls
import "../../"
import "RichNotes" as Native

FocusScope {
    id: root
    property alias text: area.text
    readonly property alias multilineEditor: area
    readonly property bool hasFocus: area.activeFocus
    property color baseColor: ThemeBackend.surface0
    property color textColor: ThemeBackend.text
    property real bgOpacity: ThemeBackend.elementOpacity
    property real cornerRadius: 8
    property int fontPixelSize: 14
    property string placeholderText: "Start writing…"
    property int revision: 0
    readonly property var paragraphStyle: {
        let change = revision;
        return document.styleAt(area.cursorPosition);
    }
    readonly property bool isBold: paragraphStyle.bold === true
    readonly property bool isItalic: paragraphStyle.italic === true
    readonly property bool isUnderline: paragraphStyle.underline === true
    signal textEdited()
    signal formatRequested(string kind)
    signal pasteRequested()
    function forceInputFocus() { area.forceActiveFocus(); }
    function releaseFocus() { area.focus = false; root.focus = false; }
    function html() { return document.html(); }
    function plainText() { return document.plainText(); }
    function fromMarkdown(source) { return document.fromMarkdown(source); }
    function format(kind) {
        if (kind === "undo") area.undo();
        else if (kind === "redo") area.redo();
        else document.format(kind, area.selectionStart, area.selectionEnd);
        root.revision++;
        root.forceInputFocus();
    }
    function insertImage(url, start, end) {
        area.cursorPosition = document.insertImage(url, start, end);
        root.forceInputFocus();
    }
    Native.RichDocument { id: document; document: area.textDocument; editor: area }
    Rectangle { anchors.fill: parent; radius: root.cornerRadius; color: Qt.alpha(root.baseColor, root.bgOpacity) }
    ScrollView {
        id: scroll
        anchors.fill: parent
        anchors.margins: 4
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        TextArea {
            id: area
            width: scroll.availableWidth
            padding: 12
            color: root.textColor
            placeholderText: root.placeholderText
            placeholderTextColor: ThemeBackend.subtext0
            font.family: "sans-serif"
            font.pixelSize: root.fontPixelSize
            textFormat: TextEdit.RichText
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            persistentSelection: true
            selectionColor: Qt.alpha(ThemeBackend.mauve, 0.32)
            selectedTextColor: root.textColor
            background: null
            onTextChanged: { root.revision++; root.textEdited(); }
            onCursorPositionChanged: root.revision++
            onSelectionStartChanged: root.revision++
            onSelectionEndChanged: root.revision++
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: event => {
                if (event.matches(StandardKey.Paste)) {
                    event.accepted = true; root.pasteRequested(); return;
                }
                if (event.modifiers & Qt.ControlModifier) {
                    let kind = "";
                    if (event.key === Qt.Key_B) kind = "bold";
                    else if (event.key === Qt.Key_I) kind = "italic";
                    else if (event.key === Qt.Key_U) kind = "underline";
                    else if (event.key === Qt.Key_Z) kind = event.modifiers & Qt.ShiftModifier ? "redo" : "undo";
                    else if (event.key === Qt.Key_Y) kind = "redo";
                    else if (event.key === Qt.Key_L && event.modifiers & Qt.ShiftModifier) kind = "bullet";
                    if (kind) { event.accepted = true; root.formatRequested(kind); return; }
                }
                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & (Qt.ShiftModifier | Qt.ControlModifier | Qt.AltModifier))) {
                    let position = document.enter(area.selectionStart, area.selectionEnd);
                    if (position >= 0) { area.cursorPosition = position; event.accepted = true; }
                } else if (event.key === Qt.Key_Backspace && area.selectionStart === area.selectionEnd) {
                    event.accepted = document.exitEmptyList(area.cursorPosition);
                }
            }
        }
    }
}
