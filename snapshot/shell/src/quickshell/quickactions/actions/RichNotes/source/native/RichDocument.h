#pragma once
#include <QQuickTextDocument>
#include <QTextBlock>
#include <QTextCursor>
#include <QTextDocument>
#include <QTextList>
#include <QTextImageFormat>
#include <QPointer>
#include <QUrl>
#include <QVariantMap>
#include <QtQuick/private/qquicktextedit_p_p.h>
#include <QtQuick/private/qquicktextcontrol_p.h>
#include <QtQuick/private/qquicktextcontrol_p_p.h>
#include <algorithm>

// Operate on Qt's document in place. Never reconstruct unselected fragments.
class RichDocument : public QObject {
    Q_OBJECT
    Q_PROPERTY(QQuickTextDocument *document READ document WRITE setDocument NOTIFY documentChanged)
    Q_PROPERTY(QQuickItem *editor READ editor WRITE setEditor NOTIFY documentChanged)
public:
    explicit RichDocument(QObject *parent = nullptr) : QObject(parent) {}
    QQuickItem *editor() const { return m_editor; }
    void setEditor(QQuickItem *value) { m_editor = value; emit documentChanged(); }
    QQuickTextDocument *document() const { return m_quick; }
    void setDocument(QQuickTextDocument *value) {
        if (value == m_quick) return;
        m_quick = value;
        m_doc = value ? value->textDocument() : nullptr;
        emit documentChanged();
    }
    void useDocument(QTextDocument *value) { m_doc = value; } // regression harness
    Q_INVOKABLE QString html() const { return m_doc ? m_doc->toHtml() : QString(); }
    Q_INVOKABLE QString plainText() const { return m_doc ? m_doc->toPlainText() : QString(); }
    Q_INVOKABLE QString fromMarkdown(const QString &source) const {
        QTextDocument legacy;
        legacy.setMarkdown(source);
        return legacy.toHtml();
    }
    Q_INVOKABLE QVariantMap styleAt(int position) const {
        if (!m_doc) return {};
        QTextCursor c = cursor(position, position);
        if (auto control = textControl()) c = static_cast<QQuickTextControlPrivate *>(QObjectPrivate::get(control))->cursor;
        auto list = c.currentList();
        return {{"heading", c.blockFormat().headingLevel()},
                {"bold", c.charFormat().fontWeight() >= QFont::Bold},
                {"italic", c.charFormat().fontItalic()},
                {"underline", c.charFormat().fontUnderline()},
                {"bullet", list && list->format().style() == QTextListFormat::ListDisc},
                {"number", list && list->format().style() == QTextListFormat::ListDecimal}};
    }
    Q_INVOKABLE void format(const QString &kind, int start, int end) {
        if (!m_doc) return;
        QTextCursor c = cursor(start, end);
        if (auto control = textControl()) c = static_cast<QQuickTextControlPrivate *>(QObjectPrivate::get(control))->cursor;
        c.beginEditBlock();
        if (kind == "bold" || kind == "italic" || kind == "underline") {
            QTextCharFormat f;
            if (kind == "bold") f.setFontWeight(c.charFormat().fontWeight() >= QFont::Bold ? QFont::Normal : QFont::Bold);
            else if (kind == "italic") f.setFontItalic(!c.charFormat().fontItalic());
            else f.setFontUnderline(!c.charFormat().fontUnderline());
            c.mergeCharFormat(f);
        } else if (kind == "bullet" || kind == "number") {
            const auto style = kind == "bullet" ? QTextListFormat::ListDisc : QTextListFormat::ListDecimal;
            bool allMatch = true;
            const int last = std::max(start, end - 1);
            for (auto b = m_doc->findBlock(start); b.isValid() && b.position() <= last; b = b.next())
                allMatch = allMatch && b.textList() && b.textList()->format().style() == style;
            if (allMatch) {
                for (auto b = m_doc->findBlock(start); b.isValid() && b.position() <= last; b = b.next()) {
                    QTextCursor block(b);
                    if (b.textList()) b.textList()->remove(b);
                    auto f = block.blockFormat(); f.setIndent(0); block.setBlockFormat(f);
                }
            } else {
                QTextListFormat f;
                f.setStyle(style); f.setIndent(1);
                // Qt's createList includes the block containing the end cursor.
                if (end > start && m_doc->findBlock(end).position() == end)
                    c.setPosition(end - 1, QTextCursor::KeepAnchor);
                c.createList(f);
            }
        } else {
            bool ok = false;
            int level = kind.toInt(&ok);
            if (ok && level >= 0 && level <= 3) {
                int last = std::max(start, end - 1);
                for (auto b = m_doc->findBlock(start); b.isValid() && b.position() <= last; b = b.next()) {
                    QTextCursor block(b);
                    auto f = block.blockFormat();
                    f.setHeadingLevel(level);
                    f.setTopMargin(level ? 8 : 0); f.setBottomMargin(level ? 6 : 0);
                    block.setBlockFormat(f);
                    block.select(QTextCursor::BlockUnderCursor);
                    QTextCharFormat chars;
                    chars.setFontWeight(level ? QFont::Bold : QFont::Normal);
                    chars.setProperty(QTextFormat::FontSizeAdjustment, level ? 4 - level : 0);
                    // Remove explicit sizes inherited from pasted or legacy headings.
                    chars.setFontPointSize(m_doc->defaultFont().pointSizeF() > 0
                                           ? m_doc->defaultFont().pointSizeF() * (level == 1 ? 1.8 : level == 2 ? 1.5 : level == 3 ? 1.2 : 1)
                                           : 10 * (level == 1 ? 1.8 : level == 2 ? 1.5 : level == 3 ? 1.2 : 1));
                    block.mergeCharFormat(chars);
                    block.mergeBlockCharFormat(chars);
                    if (!c.hasSelection()) c.setCharFormat(block.charFormat());
                }
            }
        }
        c.endEditBlock();
        syncCursor(c);
    }
    // Return continues a real list, and an empty item exits it. Headings return to body text.
    Q_INVOKABLE int enter(int start, int end) {
        if (!m_doc) return -1;
        QTextCursor c = cursor(start, end);
        auto list = c.currentList();
        if (!list && !c.blockFormat().headingLevel()) return -1;
        c.beginEditBlock();
        if (list && !c.hasSelection() && c.block().text().isEmpty()) {
            list->remove(c.block());
            auto f = c.blockFormat(); f.setIndent(0); c.setBlockFormat(f);
        } else {
            const bool heading = c.blockFormat().headingLevel() != 0;
            c.insertBlock();
            if (heading) {
                auto f = c.blockFormat(); f.setHeadingLevel(0); f.setTopMargin(0); f.setBottomMargin(0);
                c.setBlockFormat(f);
                QTextCharFormat normal;
                c.setCharFormat(normal);
                c.setBlockCharFormat(normal);
            }
        }
        c.endEditBlock();
        syncCursor(c);
        return c.position();
    }
    Q_INVOKABLE bool exitEmptyList(int position) {
        if (!m_doc) return false;
        QTextCursor c = cursor(position, position);
        if (!c.currentList() || !c.block().text().isEmpty()) return false;
        c.beginEditBlock();
        c.currentList()->remove(c.block());
        auto f = c.blockFormat(); f.setIndent(0); c.setBlockFormat(f);
        c.endEditBlock();
        return true;
    }
    Q_INVOKABLE int insertImage(const QString &url, int start, int end) {
        if (!m_doc || !QUrl(url).isLocalFile()) return start;
        QTextCursor c = cursor(start, end);
        c.beginEditBlock();
        c.removeSelectedText();
        if (c.positionInBlock()) c.insertBlock();
        QTextImageFormat image;
        image.setName(url); image.setWidth(280);
        c.insertImage(image);
        c.insertBlock();
        c.endEditBlock();
        return c.position();
    }
signals:
    void documentChanged();
private:
    QTextCursor cursor(int start, int end) const {
        QTextCursor c(m_doc);
        const int limit = m_doc->characterCount() - 1;
        c.setPosition(std::clamp(start, 0, limit));
        c.setPosition(std::clamp(end, 0, limit), QTextCursor::KeepAnchor);
        return c;
    }
    QPointer<QQuickTextDocument> m_quick;
    QPointer<QQuickItem> m_editor;
    QPointer<QTextDocument> m_doc;
    void syncCursor(const QTextCursor &value) {
        auto control = textControl();
        if (!control) return;
        // Preserve the insertion format even for an empty document. Public
        // TextSelection currently ignores that case. The plugin is Qt-version guarded.
        if (!value.hasSelection() && m_editor->property("cursorPosition").toInt() != value.position())
            m_editor->setProperty("cursorPosition", value.position());
        static_cast<QQuickTextControlPrivate *>(QObjectPrivate::get(control))->cursor = value;
        QMetaObject::invokeMethod(control, "currentCharFormatChanged", Qt::DirectConnection,
                                  Q_ARG(QTextCharFormat, value.charFormat()));
    }
    QQuickTextControl *textControl() const {
        auto edit = qobject_cast<QQuickTextEdit *>(m_editor.data());
        return edit ? QQuickTextEditPrivate::get(edit)->control : nullptr;
    }
};
