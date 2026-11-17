pragma Singleton
import QtQuick

QtObject {
    id: root
    property bool widgetEditorOpen: false
    property var bars: ({})
    property string activePopup: "hidden"
    property string popupScreen: ""
    readonly property var barPopups: ["volume", "network", "music", "calendar", "notifications", "system"]
    function publish(name, rect) {
        if (JSON.stringify(bars[name]) === JSON.stringify(rect)) return;
        let next = Object.assign({}, bars);
        next[name] = rect;
        bars = next;
    }
    function remove(name) {
        let next = Object.assign({}, bars);
        delete next[name];
        bars = next;
    }
    function holdsOpen(name) {
        return popupScreen === name && barPopups.includes(activePopup);
    }
}
