#include <QGuiApplication>
#include <QTextDocumentFragment>
#include "../native/RichDocument.h"
#include <iostream>
#include <cstdlib>

void require(bool condition, const char *message) {
    if (!condition) { std::cerr << "FAIL: " << message << '\n'; std::exit(1); }
}
int main(int argc, char **argv) {
    QGuiApplication app(argc, argv);
    QTextDocument doc;
    RichDocument backend;
    backend.useDocument(&doc);
    doc.setPlainText("first paragraph\nsecond paragraph\nthird paragraph");
    QTextCursor c(&doc);
    c.setPosition(6); c.setPosition(15, QTextCursor::KeepAnchor);
    QTextCharFormat strong; strong.setFontWeight(QFont::Bold); c.mergeCharFormat(strong);
    backend.format("2", 16, 20);
    require(doc.toPlainText() == "first paragraph\nsecond paragraph\nthird paragraph", "heading does not lose adjacent text");
    QTextDocument reopened;
    reopened.setHtml(backend.html());
    require(reopened.toPlainText() == doc.toPlainText(), "HTML round trip preserves paragraphs");
    QTextCursor check(&reopened); check.setPosition(10);
    require(check.charFormat().fontWeight() == QFont::Bold, "bold survives saving and reopening");
    require(reopened.findBlock(16).blockFormat().headingLevel() == 2, "heading survives saving and reopening");
    const auto beforeList = backend.html();
    backend.format("bullet", 16, doc.characterCount() - 1);
    require(doc.findBlock(16).textList() && doc.lastBlock().textList(), "bullets apply to all selected paragraphs");
    require(!doc.firstBlock().textList(), "bullets preserve unselected paragraphs");
    reopened.setHtml(backend.html());
    require(reopened.lastBlock().textList(), "real lists survive reopening");
    doc.undo(); require(backend.html() == beforeList, "one undo reverses the entire list operation");
    doc.redo(); require(doc.lastBlock().textList(), "native redo restores lists");
    backend.format("number", 16, doc.characterCount() - 1);
    require(doc.lastBlock().textList()->format().style() == QTextListFormat::ListDecimal, "switch bullets to numbering");
    backend.format("number", 16, doc.characterCount() - 1);
    require(!doc.lastBlock().textList(), "toggle removes numbering");
    doc.setPlainText("one\ntwo");
    backend.format("bullet", 0, 4);
    require(!doc.lastBlock().textList(), "selection ending at next paragraph start excludes that paragraph");
    int next = backend.enter(3, 3);
    require(next == 4 && doc.findBlock(next).textList(), "Enter continues a bullet list");
    next = backend.enter(next, next);
    require(!doc.findBlock(next).textList(), "Enter exits an empty bullet");
    doc.setPlainText("Title");
    backend.format("1", 0, 0);
    next = backend.enter(5, 5);
    require(doc.lastBlock().blockFormat().headingLevel() == 0, "Enter after a heading creates normal text");
    doc.setHtml(backend.fromMarkdown("# Old heading\n\n**bold** and *italic*\n\n- first\n- second"));
    require(doc.firstBlock().blockFormat().headingLevel() == 1, "legacy Markdown heading imports");
    require(doc.lastBlock().textList(), "legacy Markdown list imports");
    const auto plain = backend.plainText();
    reopened.setHtml(backend.html());
    require(reopened.toPlainText() == plain, "legacy migration round trips");
    doc.setHtml("<p>bold <b>text</b> &amp; <i>italic</i> <u>underlined</u></p>");
    reopened.setHtml(backend.html());
    require(reopened.toPlainText() == "bold text & italic underlined", "HTML escapes and inline formats round trip");
    doc.setPlainText(QString::fromUtf8("Hello 👋 café 中文\nNext line"));
    backend.format("bullet", 0, doc.characterCount() - 1);
    reopened.setHtml(backend.html());
    require(reopened.toPlainText() == doc.toPlainText(), "Unicode and newlines round trip");
    doc.setPlainText("before after");
    next = backend.insertImage("file:///tmp/notepad-test.png", 7, 7);
    const auto imageHtml = backend.html();
    require(imageHtml.contains("notepad-test.png") && imageHtml.contains("after"), "image insert preserves following text");
    reopened.setHtml(imageHtml);
    require(reopened.toHtml().contains("notepad-test.png"), "image references persist");
    std::cout << "PASS: rich-text persistence, native history, lists, headings, legacy migration, Unicode, and image references\n";
}
