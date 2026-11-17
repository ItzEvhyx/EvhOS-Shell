import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../"

PanelWindow {
    id: window
    property real reveal: 0
    property real verticalOffset: 24
    NumberAnimation {
        id: slideAnimation
        target: window
        property: "verticalOffset"
    }
    NumberAnimation {
        id: revealAnimation
        target: window
        property: "reveal"
    }
    Connections {
        target: WorkspaceOverview
        function onActiveChanged() {
            if (WorkspaceOverview.active) {
                revealAnimation.stop();
                slideAnimation.stop();
                if (window.reveal <= 0.001) window.verticalOffset = 24;
                slideAnimation.to = 0;
                slideAnimation.duration = 80;
                slideAnimation.easing.type = Easing.OutQuint;
                slideAnimation.start();
                revealAnimation.to = 1;
                revealAnimation.duration = 80;
                revealAnimation.easing.type = Easing.OutCubic;
                revealAnimation.start();
            } else {
                revealAnimation.stop();
                revealAnimation.to = 0;
                // Match the topbar/dock: quick upward slide with an 80 ms fade.
                revealAnimation.duration = 80;
                revealAnimation.easing.type = Easing.OutCubic;
                revealAnimation.start();
                slideAnimation.stop();
                slideAnimation.to = -64;
                slideAnimation.duration = 80;
                slideAnimation.easing.type = Easing.OutQuint;
                slideAnimation.start();
            }
        }
    }
    screen: WorkspaceOverview.screen || Quickshell.screens[0] || null
    color: "transparent"
    visible: WorkspaceOverview.active || window.reveal > 0.001
    onVisibleChanged: WorkspaceOverview.windowVisibilityChanged(window.visible)
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "serpantinum-workspace-overview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WorkspaceOverview.active && !WorkspaceOverview.switching ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    IpcHandler {
        target: "workspaceOverviewAppearance"
        function backgroundMode(): string { return "compositor-blur"; }
    }

    WorkspaceGrid {
        id: scene
        objectName: "workspace-overview-scene"
        anchors.fill: parent
        active: WorkspaceOverview.active
        enabled: active
        opacity: window.reveal
        entryProgress: window.reveal
        verticalOffset: window.verticalOffset
        capturePreviews: WorkspaceOverview.active || window.reveal > 0.001
        workspaceIds: WorkspaceOverview.ids
        currentWorkspace: WorkspaceOverview.focusedId
        workspaceLookup: id => WorkspaceOverview.workspace(id)
        fallbackMonitor: window.screen ? Hyprland.monitorFor(window.screen) : null
        errorText: WorkspaceOverview.errorText
        switching: WorkspaceOverview.switching
        onAccepted: id => WorkspaceOverview.jump(id)
        onCanceled: WorkspaceOverview.hide()
    }
}
