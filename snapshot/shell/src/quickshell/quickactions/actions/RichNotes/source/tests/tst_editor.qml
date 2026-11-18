import QtQuick
import QtTest
import "fixture/quickactions/actions"

TestCase {
    name: "RichNoteEditor"
    width: 470; height: 560
    when: windowShown
    RichNoteEditor { id: editor; anchors.fill: parent; onFormatRequested: kind => editor.format(kind) }
    function init() { editor.text = "<p>alpha beta gamma</p>"; editor.forceInputFocus(); }
    function test_inline_persists() {
        let area = editor.multilineEditor;
        area.select(6, 10);
        editor.format("bold");
        editor.format("italic");
        editor.format("underline");
        let saved = editor.html();
        compare(editor.plainText(), "alpha beta gamma");
        editor.text = ""; editor.text = saved;
        area.select(6, 10);
        verify(editor.isBold); verify(editor.isItalic); verify(editor.isUnderline);
        area.select(0, 5);
        verify(!editor.isBold); verify(!editor.isItalic); verify(!editor.isUnderline);
    }
    function test_undo_redo() {
        let area = editor.multilineEditor;
        area.select(6, 10); editor.format("bold");
        verify(editor.isBold);
        editor.format("undo"); verify(!editor.isBold);
        editor.format("redo"); verify(editor.isBold);
    }
    function test_typing_with_bold() {
        let area = editor.multilineEditor;
        area.cursorPosition = area.length;
        editor.format("bold");
        keyClick(Qt.Key_X);
        compare(editor.plainText(), "alpha beta gammax");
        let saved = editor.html(); editor.text = ""; editor.text = saved;
        area.select(16, 17); verify(editor.isBold);
        area.select(11, 16); verify(!editor.isBold);
    }
    function test_bullet_enter_and_exit() {
        editor.text = "<p>first</p>";
        let area = editor.multilineEditor;
        area.cursorPosition = 5; editor.format("bullet");
        verify(editor.paragraphStyle.bullet);
        keyClick(Qt.Key_Return); keyClick(Qt.Key_A);
        compare(editor.plainText(), "first\na");
        verify(editor.paragraphStyle.bullet);
        keyClick(Qt.Key_Return); keyClick(Qt.Key_Return);
        verify(!editor.paragraphStyle.bullet);
    }
    function test_heading_enter() {
        let area = editor.multilineEditor;
        area.cursorPosition = area.length; editor.format("1");
        compare(editor.paragraphStyle.heading, 1);
        keyClick(Qt.Key_Return); keyClick(Qt.Key_X);
        compare(editor.paragraphStyle.heading, 0);
        verify(!editor.isBold);
    }
    function test_empty_heading_typing() {
        editor.text = "";
        editor.format("2"); keyClick(Qt.Key_H);
        compare(editor.plainText(), "h");
        verify(editor.isBold);
        editor.text = editor.html();
        compare(editor.paragraphStyle.heading, 2);
    }
    function test_empty_bold_typing() {
        editor.text = "";
        editor.format("bold"); keyClick(Qt.Key_B);
        verify(editor.isBold);
        editor.format("bold"); keyClick(Qt.Key_N);
        editor.text = editor.html();
        editor.multilineEditor.select(0, 1); verify(editor.isBold);
        editor.multilineEditor.select(1, 2); verify(!editor.isBold);
    }
    function test_keyboard_shortcuts() {
        editor.multilineEditor.select(0, 5);
        keyClick(Qt.Key_B, Qt.ControlModifier);
        verify(editor.isBold);
        keyClick(Qt.Key_Z, Qt.ControlModifier);
        verify(!editor.isBold);
    }
    function test_legacy_markdown() {
        editor.text = editor.fromMarkdown("# Title\n\n**Bold** and *italic*\n\n- first\n- second");
        compare(editor.plainText(), "Title\nBold and italic\nfirst\nsecond");
        let saved = editor.html(); editor.text = ""; editor.text = saved;
        compare(editor.plainText(), "Title\nBold and italic\nfirst\nsecond");
    }
}
