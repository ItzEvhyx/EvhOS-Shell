pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Item {
    id: root
    readonly property string scriptPath: (Caching.serpantinumDir || (Caching.home + "/.local/share/serpantinum/src")) + "/scripts/desktop-presets.py"
    property var state: ({
            presets: [],
            activeName: "",
            modified: false,
            changedSections: [],
            activeFingerprint: "",
            session: null,
            canUndo: false,
            warnings: [],
            history: []
        })
    readonly property var session: state.session || null
    readonly property bool editing: !!session
    readonly property bool busy: actionProcess.running || !!deferredAction || Config.desktopPresetApplying
    readonly property bool hasDialog: nameRequested || !!reviewData || reviewLoading || saveConfirmName !== "" || deleteName !== "" || discardConfirm
    property string message: ""
    property bool error: false
    property int viewers: 0
    property string actionOutput: ""
    property string statusOutput: ""
    property string actionStderr: ""
    property string actionKind: ""
    property var nextAction: null
    property var pendingAction: null
    property bool nameRequested: false
    property string nameAction: "save"
    property string nameSource: ""
    property var afterSave: null
    property string saveConfirmName: ""
    property string saveExpected: ""
    property string deleteName: ""
    property bool discardConfirm: false
    property var reviewData: null
    property bool reviewLoading: false
    property var reviewSelection: []
    property bool keepPinnedApps: false
    readonly property bool autosaveRunning: autosaveProcess.running
    property string autosaveOutput: ""
    property string autosaveError: ""
    property bool autosavePending: false
    property var deferredAction: null

    function refresh() {
        if (!statusProcess.running && !busy)
            statusProcess.running = true;
    }
    function componentLabel(key) {
        return ({
                theme: "Appearance",
                bar: "Topbar",
                dock: "Dock",
                widgets: "Widgets",
                wallpaper: "Wallpaper"
            })[key] || key;
    }
    function changedText() {
        return (state.changedSections || []).map(componentLabel).join(" · ");
    }
    function perform(action, name, target, followUp, options) {
        if (busy)
            return;
        if (autosaveProcess.running) {
            deferredAction = {
                action: action,
                name: name,
                target: target,
                followUp: followUp,
                options: options
            };
            return;
        }
        nextAction = followUp || null;
        actionKind = action;
        error = false;
        message = action === "review" ? "" : (["apply", "restore"].includes(action) ? "Saving a recovery snapshot and switching…" : "Working…");
        actionOutput = "";
        actionStderr = "";
        let args = ["python3", scriptPath, "--json"];
        let opts = options || {};
        if (opts.source)
            args.push("--source", opts.source);
        if (opts.sections)
            args.push("--sections", opts.sections.join(","));
        if (opts.keepApps)
            args.push("--keep-apps");
        if (opts.expected)
            args.push("--expected", opts.expected);
        args.push(action);
        if (name || target)
            args.push(name || "");
        if (target)
            args.push(target);
        actionProcess.command = args;
        actionProcess.running = true;
    }
    function request(action, name) {
        if (busy)
            return;
        if (action === "apply") {
            openReview(name, "preset");
            return;
        }
        if (action === "restore") {
            openReview(name, "history");
            return;
        }
        if (action === "update") {
            openUpdate(name || state.activeName);
            return;
        }
        if (action === "discard") {
            discardConfirm = true;
            return;
        }
        perform(action, name || "");
    }
    function openReview(name, source) {
        if (busy || !name)
            return;
        reviewData = null;
        reviewLoading = true;
        perform("review", name, "", null, {
            source: source || "preset"
        });
    }
    function setComponent(key, selected) {
        let choices = reviewSelection.filter(value => value !== key);
        if (selected)
            choices.push(key);
        reviewSelection = choices;
    }
    function switchAction() {
        if (!reviewData || reviewSelection.length === 0)
            return null;
        return {
            action: reviewData.source === "history" ? "restore" : "apply",
            name: reviewData.name,
            options: {
                source: reviewData.source,
                expected: reviewData.fingerprint,
                sections: reviewSelection.slice(),
                keepApps: keepPinnedApps
            }
        };
    }
    function confirmSwitch() {
        let next = switchAction();
        if (next && !busy)
            perform(next.action, next.name, "", null, next.options);
    }
    function saveCopyBeforeSwitch() {
        if (busy)
            return;
        afterSave = switchAction();
        openName("save", "", true);
    }
    function cancelReview() {
        if (busy)
            return;
        reviewData = null;
        reviewLoading = false;
        afterSave = null;
    }
    function openUpdate(name) {
        if (busy || !name)
            return;
        let preset = (state.presets || []).find(item => item.name === name);
        if (!preset) {
            openName("save", "");
            return;
        }
        saveConfirmName = name;
        saveExpected = preset.fingerprint || "";
    }
    function confirmUpdate() {
        if (!busy && saveConfirmName)
            perform("update", saveConfirmName, "", null, {
                expected: saveExpected
            });
    }
    function openName(action, source, preserveFollowUp) {
        if (busy)
            return;
        if (!preserveFollowUp)
            afterSave = null;
        nameAction = action;
        nameSource = source || "";
        nameRequested = true;
    }
    function nameProblem(name) {
        name = name.trim();
        if (!name)
            return "";
        if (!/^[A-Za-z0-9][A-Za-z0-9 _-]{0,63}$/.test(name))
            return "Use letters, numbers, spaces, underscores or hyphens.";
        let duplicate = (state.presets || []).some(item => item.name.toLowerCase() === name.toLowerCase() && !(nameAction === "rename" && item.name === nameSource));
        return duplicate ? "A theme with that name exists. Choose a different name." : "";
    }
    function submitName(name) {
        name = name.trim();
        if (!name || busy || nameProblem(name))
            return;
        let followUp = nameAction === "save" ? afterSave : null;
        afterSave = null;
        perform(nameAction, nameAction === "save" ? name : nameSource, nameAction === "save" ? "" : name, followUp);
    }
    function save() {
        if (busy)
            return;
        let name = session && session.name ? session.name : state.activeName;
        if (name)
            openUpdate(name);
        else
            openName("save", "");
    }
    function arrangeWidgets() {
        if (busy || !editing)
            return;
        Quickshell.execDetached(["quickshell", "-p", Caching.mainQml || Qt.resolvedUrl("../../Shell.qml").toString().replace("file://", ""), "ipc", "call", "redactor", "activate"]);
    }
    function openSettings(tab) {
        PanelActions.invoke("open", "settings", tab || "preset_themes");
    }
    function dismissDialog() {
        if (busy)
            return;
        nameRequested = false;
        saveConfirmName = "";
        deleteName = "";
        discardConfirm = false;
        reviewData = null;
        reviewLoading = false;
        afterSave = null;
    }
    function resolvePending(choice) {
        pendingAction = null;
        if (choice === "save")
            save();
        else if (choice === "discard")
            discardConfirm = true;
    }
    IpcHandler {
        target: "desktopPresetUi"
        function version(): string {
            return "4";
        }
        function notificationVersion(): string {
            return "1";
        }
    }
    Process {
        id: actionProcess
        stdout: StdioCollector {
            onStreamFinished: root.actionOutput = text
        }
        stderr: StdioCollector {
            onStreamFinished: root.actionStderr = text
        }
        onExited: function (code) {
            let kind = root.actionKind;
            let followUp = root.nextAction;
            root.nextAction = null;
            root.reviewLoading = false;
            try {
                let response = JSON.parse(root.actionOutput);
                if (code !== 0 || !response.ok)
                    throw new Error(response.error || root.actionStderr || "Theme operation failed.");
                root.error = false;
                if (["save", "update", "apply", "restore", "autosave"].includes(kind))
                    root.autosaveError = "";
                if (kind === "review") {
                    root.reviewData = response.result;
                    root.keepPinnedApps = false;
                    root.reviewSelection = response.result.components.map(item => item.key);
                    return;
                }
                root.message = response.result.message || "Done.";
                root.nameRequested = false;
                root.saveConfirmName = "";
                root.deleteName = "";
                root.discardConfirm = false;
                if (kind === "apply" || kind === "restore" || followUp)
                    root.reviewData = null;
                if (followUp)
                    Qt.callLater(() => root.perform(followUp.action, followUp.name, "", null, followUp.options));
                else
                    Qt.callLater(root.refresh);
            } catch (error) {
                root.error = true;
                root.message = String(error).replace(/^Error: /, "");
                Qt.callLater(root.refresh);
            }
        }
    }
    Process {
        id: statusProcess
        command: ["python3", root.scriptPath, "--json", "status"]
        stdout: StdioCollector {
            onStreamFinished: root.statusOutput = text
        }
        onExited: function (code) {
            try {
                let response = JSON.parse(root.statusOutput);
                if (code !== 0 || !response.ok)
                    throw new Error(response.error || "Could not read desktop themes.");
                if (JSON.stringify(root.state) !== JSON.stringify(response.result))
                    root.state = response.result;
                if (root.state.modified && !root.autosaveError)
                    root.scheduleAutosave();
            } catch (error) {
                if (!root.busy) {
                    root.error = true;
                    root.message = String(error).replace(/^Error: /, "");
                }
            }
        }
    }
    FileView {
        path: Caching.stateDir + "/desktop-preset-session.json"
        watchChanges: true
        onFileChanged: {
            reload();
            refreshDebounce.restart();
        }
    }
    Timer {
        id: refreshDebounce
        interval: 140
        onTriggered: root.refresh()
    }
    Timer {
        interval: root.editing ? 1000 : 4000
        running: root.editing || root.viewers > 0 || root.hasDialog
        repeat: true
        onTriggered: root.refresh()
    }
    // One authoritative, debounced autosave worker in the main shell. Settings
    // windows observe its results rather than racing to save the same theme.
    function scheduleAutosave() {
        if (Caching.isStandalone || editing || Config.desktopPresetApplying)
            return;
        autosavePending = true;
        autosaveDebounce.restart();
    }
    function saveNow() {
        autosavePending = true;
        startAutosave();
    }
    function startAutosave() {
        if (Caching.isStandalone) {
            perform("autosave", "");
            return;
        }
        if (busy || hasDialog || editing || autosaveProcess.running || !state.activeName)
            return;
        autosavePending = false;
        autosaveOutput = "";
        autosaveProcess.running = true;
    }
    onHasDialogChanged: if (!hasDialog && autosavePending)
        autosaveDebounce.restart()
    onBusyChanged: if (!busy && autosavePending)
        autosaveDebounce.restart()
    Timer {
        id: autosaveDebounce
        interval: 1000
        onTriggered: root.startAutosave()
    }
    Connections {
        target: Config
        ignoreUnknownSignals: true
        function onRawSettingsChanged() {
            root.scheduleAutosave();
        }
    }
    Connections {
        target: typeof Wallpaper !== "undefined" ? Wallpaper : null
        ignoreUnknownSignals: true
        function onScreenWallpaperPathsChanged() {
            root.scheduleAutosave();
        }
    }
    Repeater {
        model: Caching.isStandalone ? [] : Quickshell.screens
        delegate: Item {
            id: monitorWatcher
            required property var modelData
            FileView {
                path: Caching.stateDir + "/widgets/" + monitorWatcher.modelData.name + "/layout.json"
                watchChanges: true
                onFileChanged: {
                    reload();
                    root.scheduleAutosave();
                }
            }
        }
    }
    Process {
        id: autosaveProcess
        command: ["python3", root.scriptPath, "--json", "--no-notify", "autosave"]
        stdout: StdioCollector {
            onStreamFinished: root.autosaveOutput = text
        }
        onExited: function (code) {
            try {
                let response = JSON.parse(root.autosaveOutput);
                if (code !== 0 || !response.ok)
                    throw new Error(response.error || "Autosave did not finish.");
                root.autosaveError = "";
                if (response.result.retry) {
                    root.autosavePending = true;
                    autosaveDebounce.restart();
                }
            } catch (error) {
                let text = String(error).replace(/^Error: /, "");
                if (text.includes("Another preset operation")) {
                    root.autosavePending = true;
                    autosaveDebounce.restart();
                } else
                    root.autosaveError = text;
            }
            let deferred = root.deferredAction;
            root.deferredAction = null;
            if (deferred)
                Qt.callLater(() => root.perform(deferred.action, deferred.name, deferred.target, deferred.followUp, deferred.options));
            else
                Qt.callLater(root.refresh);
            if (root.autosavePending)
                autosaveDebounce.restart();
        }
    }
    Component.onCompleted: refresh()
}
