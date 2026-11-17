import QtQuick
import Quickshell
import Quickshell.Wayland
import "../"

Variants {
    model: Quickshell.screens
    delegate: PanelWindow {
        id: window
        required property var modelData
        screen: modelData
        readonly property bool settingsFocused: ToplevelManager.activeToplevel && ToplevelManager.activeToplevel.appId === "serpantinum-settings"
        visible: !PrivacyMode.active && (DesktopPresets.editing || strip.hasDialog) && !settingsFocused && !BarGeometry.widgetEditorOpen
                 && (!BarGeometry.activePopup || BarGeometry.activePopup === "hidden")
        color: "transparent"
        anchors { top: true }
        implicitWidth: Math.max(1, Math.min(Math.round(Scaler.s(780)), screen.width - Math.round(Scaler.s(24))))
        implicitHeight: strip.implicitHeight
        margins.top: {
            let bar = BarGeometry.bars[screen.name];
            return Math.round(Scaler.s(10)) + (bar && bar.position === "top" ? bar.y + bar.height : 0);
        }
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        WlrLayershell.namespace: "qs-desktop-preset-editor"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: strip.hasDialog ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        DesktopPresetSessionBar { id: strip; anchors.fill: parent; desktop: true; onNavigate: tab => DesktopPresets.openSettings(tab); onArrange: DesktopPresets.arrangeWidgets() }
    }
}
