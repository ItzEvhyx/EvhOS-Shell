pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root
    // Session-only: never save a blackout into desktop presets or settings.
    property bool active: false
    readonly property bool canDismiss: active && !armTimer.running

    function activate() { if (!active) active = true; }
    function deactivate() { active = false; }
    function toggle() { active = !active; }

    onActiveChanged: {
        if (active) armTimer.restart();
        else armTimer.stop();
    }

    Timer { id: armTimer; interval: 500 }

    IpcHandler {
        target: "privacy"
        function enable(): void { root.activate(); }
        function disable(): void { root.deactivate(); }
        function toggle(): void { root.toggle(); }
    }
}
