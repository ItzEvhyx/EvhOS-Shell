#include <QQmlExtensionPlugin>
#include "RichDocument.h"

class NotesPlugin : public QQmlExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)
public:
    void registerTypes(const char *uri) override {
        if (QString::fromLatin1(qVersion()) != QString::fromLatin1(QT_VERSION_STR)) {
            qmlRegisterTypeNotAvailable(uri, 1, 0, "RichDocument",
                "Notepad needs rebuilding after the Qt update. Run install-rich-notepad.py again.");
            return;
        }
        qmlRegisterType<RichDocument>(uri, 1, 0, "RichDocument");
    }
};
#include "NotesPlugin.moc"
