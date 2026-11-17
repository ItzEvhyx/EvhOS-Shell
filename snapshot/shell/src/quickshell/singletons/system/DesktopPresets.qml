pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Item {
    id: root
    readonly property string scriptPath: (Caching.serpantinumDir || (Caching.home + "/.local/share/serpantinum/src")) + "/scripts/desktop-presets.py"
    property var state: ({ presets: [], activeName: "", modified: false, session: null, canUndo: false, warnings: [] })
    readonly property var session: state.session || null
    readonly property bool editing: !!session
    readonly property bool busy: actionProcess.running || Config.desktopPresetApplying
    property string message: ""
    property bool error: false
    property var pendingAction: null
    property var nextAction: null
    property bool nameRequested: false
    property string nameAction: "save"
    property string nameSource: ""
    property string deleteName: ""
    property string actionOutput: ""
    property string statusOutput: ""
    property string actionStderr: ""
    property int viewers: 0

    function refresh() {
        if (!statusProcess.running && !busy) statusProcess.running = true;
    }
    function perform(action, name, target, followUp) {
        if (busy) return;
        nextAction = followUp || null;
        error = false;
        message = action === "discard" ? "Restoring your previous desktop…" : "Working…";
        actionOutput = "";
        actionStderr = "";
        let args = ["python3", scriptPath, "--json", action];
        // Switching away from an untouched preview is cleanup, not a user discard.
        if (action === "discard" && followUp && session && !session.dirty)
            args.push("--no-notify");
        if (name || target) args.push(name || "");
        if (target) args.push(target);
        actionProcess.command = args;
        actionProcess.running = true;
    }
    function request(action, name) {
        if (busy) return;
        let replacement = ["apply", "begin", "undo"].includes(action);
        if (replacement && editing) {
            let next = {action: action, name: name || ""};
            if (session.dirty || session.isNew) pendingAction = next;
            else perform("discard", "", "", next);
            return;
        }
        perform(action, name || "");
    }
    function resolvePending(choice) {
        if (!pendingAction || busy) return;
        if (choice === "cancel") { pendingAction = null; return; }
        let next = pendingAction;
        if (choice === "save" && (!session || session.isNew)) {
            openName("save", "");
            return;
        }
        pendingAction = null;
        perform(choice === "save" ? "update" : "discard", "", "", next);
    }
    function openName(action, source) {
        if (busy) return;
        nameAction = action;
        nameSource = source || "";
        nameRequested = true;
    }
    function submitName(name) {
        name = name.trim();
        if (!name || busy) return;
        let next = nameAction === "save" ? pendingAction : null;
        pendingAction = null;
        perform(nameAction, nameAction === "save" ? name : nameSource,
                nameAction === "save" ? "" : name, next);
    }
    function save() {
        if (!editing || busy) return;
        if (session.isNew) openName("save", "");
        else perform("update", "");
    }
    function arrangeWidgets() {
        if (busy || !editing) return;
        Quickshell.execDetached(["quickshell", "-p", Caching.mainQml || Qt.resolvedUrl("../../Shell.qml").toString().replace("file://", ""), "ipc", "call", "redactor", "activate"]);
    }
    function openSettings(tab) {
        PanelActions.invoke("open", "settings", tab || "theme");
    }

    IpcHandler {
        target: "desktopPresetUi"
        function version(): string { return "2"; }
        function notificationVersion(): string { return "1"; }
    }

    Process {
        id: actionProcess
        stdout: StdioCollector { onStreamFinished: root.actionOutput = text }
        stderr: StdioCollector { onStreamFinished: root.actionStderr = text }
        onExited: function(code) {
            let followUp = root.nextAction;
            root.nextAction = null;
            try {
                let response = JSON.parse(root.actionOutput);
                if (code !== 0 || !response.ok) throw new Error(response.error || root.actionStderr || "Preset operation failed.");
                root.error = false;
                root.message = response.result.message || "Done.";
                root.nameRequested = false;
                root.deleteName = "";
                if (followUp) Qt.callLater(() => root.perform(followUp.action, followUp.name));
                else Qt.callLater(root.refresh);
            } catch (e) {
                root.error = true;
                if (followUp) root.pendingAction = followUp;
                root.message = String(e).replace(/^Error: /, "");
                Qt.callLater(root.refresh);
            }
        }
    }
    Process {
        id: statusProcess
        command: ["python3", root.scriptPath, "--json", "status"]
        stdout: StdioCollector { onStreamFinished: root.statusOutput = text }
        onExited: function(code) {
            try {
                let response = JSON.parse(root.statusOutput);
                if (code !== 0 || !response.ok) throw new Error(response.error || "Could not read desktop presets.");
                root.state = response.result;
            } catch (e) {
                if (!root.busy) { root.error = true; root.message = String(e).replace(/^Error: /, ""); }
            }
        }
    }
    FileView {
        path: Caching.stateDir + "/desktop-preset-session.json"
        watchChanges: true
        onFileChanged: { reload(); refreshDebounce.restart(); }
    }
    Timer { id: refreshDebounce; interval: 120; onTriggered: root.refresh() }
    Timer {
        interval: root.editing ? 1000 : 5000
        running: !Caching.isStandalone || root.editing || root.viewers > 0
        repeat: true
        onTriggered: root.refresh()
    }
    Component.onCompleted: refresh()
}
