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
        visible: !PrivacyMode.active && (strip.presented || strip.opacity > 0.001) && !settingsFocused && !BarGeometry.widgetEditorOpen && (!BarGeometry.activePopup || BarGeometry.activePopup === "hidden")
        color: "transparent"
        anchors {
            top: true
        }
        implicitWidth: Math.max(1, Math.min(Math.round(Scaler.s(704)), screen.width - Math.round(Scaler.s(24))))
        implicitHeight: strip.implicitHeight + Math.round(Scaler.s(24))
        margins.top: {
            let bar = BarGeometry.bars[screen.name];
            return Math.round(Scaler.s(10)) + (bar && bar.position === "top" ? bar.y + bar.height : 0);
        }
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        WlrLayershell.namespace: "qs-desktop-preset-editor"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: strip.hasDialog ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        DesktopPresetSessionBar {
            id: strip
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: Math.round(Scaler.s(12))
            }
            height: implicitHeight
            maxContentHeight: Math.max(Math.round(Scaler.s(120)), window.screen.height - window.margins.top - Math.round(Scaler.s(60)))
            desktop: true
            onNavigate: tab => DesktopPresets.openSettings(tab)
            onArrange: DesktopPresets.arrangeWidgets()
        }
    }
}
