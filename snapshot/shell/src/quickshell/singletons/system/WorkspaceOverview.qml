pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../../"
import "../../overview/OverviewLogic.js" as Logic

Item {
    id: root
    property bool active: false
    property bool preparing: false
    property bool switching: false
    property bool overlayVisible: false
    property int pendingWorkspace: 0
    property int switchAttempts: 0
    property var screen: null
    property string frozenBackground: ""
    property int revision: 0
    property string errorText: ""
    property string switchOutput: ""
    property string switchErrorText: ""
    readonly property var ids: Logic.workspaceIds(Hyprland.workspaces.values, Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1)
    readonly property int focusedId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1

    function workspace(id) {
        let list = Hyprland.workspaces.values;
        for (let workspace of list) if (workspace.id === id) return workspace;
        return null;
    }

    function show() {
        if (root.active || root.preparing || root.switching || PrivacyMode.active) return;
        cleanupTimer.stop();
        let name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        root.screen = Quickshell.screens.find(screen => screen.name === name) || Quickshell.screens[0] || null;
        if (!root.screen) return;
        root.errorText = "";
        root.frozenBackground = "";
        root.preparing = false;
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
        LauncherController.hide();
        PanelActions.requested("close", "", "");
        // Show the blurred wallpaper immediately; workspace previews stay live.
        root.active = true;
    }

    function hide() {
        root.active = false;
        root.preparing = false;
        cleanupTimer.restart();
    }
    function toggle() { if (root.active || root.preparing) root.hide(); else root.show(); }

    function jump(id) {
        let target = Number(id);
        if (root.switching || !Number.isInteger(target) || target <= 0) return;
        root.switching = true;
        root.errorText = "";
        root.switchOutput = "";
        root.switchErrorText = "";
        root.pendingWorkspace = target;
        root.switchAttempts = 0;
        // Execute through the native Lua API and check the resulting focus.
        // Skip focusing an already active workspace to avoid back-and-forth binds.
        let code = "local target = " + String(target) + "; "
            + "for _, layer in ipairs(hl.get_layers({namespace = 'serpantinum-workspace-overview'})) do "
            + "assert(not layer.mapped, 'OVERVIEW_WAIT_FOR_UNMAP') end; "
            + "local special = hl.get_active_special_workspace(); "
            + "if special then local name = special.name:gsub('^special:', ''); hl.dispatch(hl.dsp.workspace.toggle_special(name)) end; "
            + "local current = hl.get_active_workspace(); "
            + "if not current or current.id ~= target then hl.dispatch(hl.dsp.focus({ workspace = tostring(target) })) end; "
            + "local active = hl.get_active_workspace(); "
            + "assert(active and active.id == target, 'Selected workspace did not become active')";
        switchProcess.command = ["hyprctl", "eval", code];
        // Release the exclusive keyboard layer before changing workspace.
        root.hide();
        root.windowVisibilityChanged(root.overlayVisible);
    }

    function windowVisibilityChanged(visible) {
        root.overlayVisible = visible;
        if (!visible && root.switching && root.pendingWorkspace > 0 && !switchProcess.running)
            switchAfterClose.restart();
    }

    Timer {
        id: switchAfterClose
        interval: 16
        onTriggered: {
            if (root.active || root.overlayVisible || !root.switching || root.pendingWorkspace <= 0) return;
            root.switchOutput = "";
            root.switchErrorText = "";
            switchProcess.running = true;
        }
    }

    IpcHandler {
        target: "workspaceOverview"
        function toggle(): void { root.toggle(); }
        function show(): void { root.show(); }
        function hide(): void { root.hide(); }
        // Avoid the CLI's reserved `show` subcommand in gesture invocations.
        function openOverview(): void { root.show(); }
        function closeOverview(): void { root.hide(); }
        function switchVersion(): string { return "3"; }
    }

    Process {
        id: switchProcess
        objectName: "overview-switch-process"
        stdout: StdioCollector { onStreamFinished: root.switchOutput = text }
        stderr: StdioCollector { onStreamFinished: root.switchErrorText = text }
        onExited: code => {
            let message = root.switchErrorText.trim() || root.switchOutput.trim() || "Could not switch workspace.";
            if (message.indexOf("OVERVIEW_WAIT_FOR_UNMAP") >= 0 && root.switchAttempts < 8) {
                root.switchAttempts++;
                switchAfterClose.restart();
                return;
            }
            root.pendingWorkspace = 0;
            root.switching = false;
            if (code !== 0 || root.switchOutput.trim() !== "ok") {
                root.show();
                root.errorText = message;
                console.warn("Workspace overview switch: " + root.errorText);
            }
        }
    }

    Timer {
        id: cleanupTimer
        interval: 320
        onTriggered: {
            if (root.active || root.preparing) return;
            root.frozenBackground = "";
        }
    }
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() { if ((root.active || root.preparing) && !root.switching) root.hide(); }
        function onRawEvent(event) {
            if (root.active && event && ["openwindow","closewindow","movewindow","movewindowv2"].indexOf(event.name) >= 0)
                Hyprland.refreshToplevels();
        }
    }
    Connections {
        target: PrivacyMode
        function onActiveChanged() { if (PrivacyMode.active) root.hide(); }
    }
}
