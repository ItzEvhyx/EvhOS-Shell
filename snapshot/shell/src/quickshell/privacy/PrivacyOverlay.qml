import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "../"

Variants {
    // Recreated on activation and for hot-plugged monitors.
    model: PrivacyMode.active ? Quickshell.screens : []
    delegate: PanelWindow {
        id: cover
        required property var modelData
        screen: modelData
        color: "#000000"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "serpantinum-privacy"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        IdleInhibitor { window: cover; enabled: PrivacyMode.active }
        ShortcutInhibitor { window: cover; enabled: PrivacyMode.active }

        Shortcut {
            sequence: "Escape"
            context: Qt.WindowShortcut
            enabled: PrivacyMode.canDismiss
            onActivated: PrivacyMode.deactivate()
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.BlankCursor
            acceptedButtons: Qt.AllButtons
            // Consume input, including the exit gesture, above the apps.
            onDoubleClicked: mouse => {
                if (mouse.button === Qt.LeftButton && PrivacyMode.canDismiss)
                    PrivacyMode.deactivate();
                mouse.accepted = true;
            }
            onWheel: wheel => { wheel.accepted = true; }
        }
    }
}
