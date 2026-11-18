pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: config

    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string userConfigDir: homeDir + "/.config/serpantinum"
    readonly property string settingsJsonPath: Quickshell.env("QS_SETTINGS") ? Quickshell.env("QS_SETTINGS") : (userConfigDir + "/settings.json")

    property bool desktopPresetApplying: false
    property string writeError: ""
    signal desktopPresetTransactionStarted()

    Timer {
        id: presetWatchdog
        interval: 120000
        onTriggered: config.desktopPresetApplying = false
    }

    property bool dataReady: false
    property var rawSettings: ({})
    property bool isWriting: false
    property var pendingPayload: null
    property string lastWrittenContent: ""

    readonly property string writerScript:
        'target="$1"\n' +
        'content="$2"\n' +
        'dir="$(dirname "$target")"\n' +
        'mkdir -p "$dir" || exit 1\n' +
        'tmp="$dir/.settings_tmp_$$\"\n' +
        'trap \'rm -f "$tmp"\' EXIT INT TERM HUP\n' +
        'printf "%s\\n" "$content" > "$tmp" || exit 1\n' +
        'if [ -s "$tmp" ]; then\n' +
        '  chmod 644 "$tmp" 2>/dev/null || true\n' +
        '  mv "$tmp" "$target"\n' +
        'fi\n'

    signal settingsLoaded()

    function areEqual(a, b) {
        if (a === b) return true;
        if (a === null || b === null || typeof a !== "object" || typeof b !== "object") return false;
        if (Array.isArray(a) !== Array.isArray(b)) return false;
        let keysA = Object.keys(a);
        let keysB = Object.keys(b);
        if (keysA.length !== keysB.length) return false;
        for (let i = 0; i < keysA.length; i++) {
            let k = keysA[i];
            if (!Object.prototype.hasOwnProperty.call(b, k)) return false;
            if (!areEqual(a[k], b[k])) return false;
        }
        return true;
    }

    function setNestedValue(obj, path, value) {
        let parts = typeof path === "string" ? path.split(".") : [path];
        let cur = obj;
        for (let i = 0; i < parts.length - 1; i++) {
            let p = parts[i];
            if (!cur[p] || typeof cur[p] !== "object") {
                cur[p] = {};
            }
            cur = cur[p];
        }
        cur[parts[parts.length - 1]] = value;
    }

    function sh(cmd) {
        Quickshell.execDetached(["bash", "-c", cmd]);
    }

    function getSetting(key, fallbackValue) {
        if (!rawSettings || typeof rawSettings !== "object") {
            if (fallbackValue !== null && typeof fallbackValue === "object") {
                try { return JSON.parse(JSON.stringify(fallbackValue)); } catch (e) { return fallbackValue; }
            }
            return fallbackValue;
        }

        let val = undefined;
        if (rawSettings.hasOwnProperty(key) && rawSettings[key] !== undefined && rawSettings[key] !== null) {
            val = rawSettings[key];
        } else if (typeof key === "string" && key.indexOf(".") !== -1) {
            let parts = key.split(".");
            let cur = rawSettings;
            for (let i = 0; i < parts.length; i++) {
                if (cur && typeof cur === "object" && cur.hasOwnProperty(parts[i])) {
                    cur = cur[parts[i]];
                } else {
                    val = fallbackValue;
                    break;
                }
            }
            if (val === undefined) {
                val = (cur !== undefined && cur !== null) ? cur : fallbackValue;
            }
        } else {
            val = fallbackValue;
        }

        if (val !== null && typeof val === "object") {
            try {
                return JSON.parse(JSON.stringify(val));
            } catch (e) {
                return val;
            }
        }
        return val;
    }

    function setSetting(key, value) {
        let obj = {};
        obj[key] = value;
        updateJsonBulk(obj);
    }

    function updateJsonBulk(dataObj) {
        let next = JSON.parse(JSON.stringify(rawSettings || {}));
        for (let key in dataObj) {
            let val = dataObj[key];
            let clonedVal = (val !== null && typeof val === "object") ? JSON.parse(JSON.stringify(val)) : val;
            if (typeof key === "string" && key.indexOf(".") !== -1) {
                setNestedValue(next, key, clonedVal);
            } else {
                next[key] = clonedVal;
            }
        }
        if (areEqual(rawSettings, next)) return;
        rawSettings = next;
        dispatchWrite(next);
    }

    function dispatchWrite(settingsObj) {
        if (isWriting) {
            pendingPayload = JSON.parse(JSON.stringify(settingsObj));
            return;
        }
        isWriting = true;
        let str = JSON.stringify(settingsObj, null, 2);
        lastWrittenContent = str;
        writerProc.command = ["bash", "-c", writerScript, "_", settingsJsonPath, str + "\n"];
        writerProc.running = true;
    }

    Process {
        id: writerProc
        command: []
        onExited: function(exitCode, exitStatus) {
            config.isWriting = false;
            config.writeError = exitCode === 0 ? "" : "Could not save desktop settings";
            if (exitCode !== 0) config.lastWrittenContent = "";
            if (config.pendingPayload !== null) {
                let next = config.pendingPayload;
                config.pendingPayload = null;
                config.dispatchWrite(next);
            } else {
                config.settingsLoaded();
            }
        }
    }

    FileView {
        id: settingsWatcher
        path: config.settingsJsonPath
        watchChanges: true
        onFileChanged: reload()

        onLoaded: {
            try {
                let raw = typeof text === "function" ? text() : text;
                if (typeof raw === "string") {
                    let trimmed = raw.trim();
                    if (config.isWriting || config.pendingPayload !== null) {
                        config.dataReady = true;
                        return;
                    }

                    if (trimmed === config.lastWrittenContent.trim()) {
                        config.dataReady = true;
                        return;
                    }
                    if (trimmed.length > 0) {
                        let parsed = JSON.parse(trimmed);
                        if (parsed && typeof parsed === "object") {
                            if (!config.areEqual(config.rawSettings, parsed)) {
                                config.rawSettings = parsed;
                                config.settingsLoaded();
                            }
                        }
                    }
                }
            } catch (e) {
            }
            config.dataReady = true;
        }
    }

    // Desktop presets must update the live configuration, not just replace its file.
    IpcHandler {
        target: "desktopPresetConfig"
        function monitors(): string {
            return JSON.stringify(Quickshell.screens.map(s => s.name));
        }
        function ready(): string {
            if (config.writeError) return config.writeError;
            return config.dataReady && !config.isWriting && config.pendingPayload === null ? "ok" : "busy";
        }
        function beginTransaction(): string {
            if (!config.dataReady) return "Configuration is not ready";
            config.desktopPresetApplying = true;
            presetWatchdog.restart();
            config.desktopPresetTransactionStarted();
            return "ok";
        }
        function endTransaction(): string {
            config.desktopPresetApplying = false;
            presetWatchdog.stop();
            return "ok";
        }
        function get(): string {
            return config.dataReady ? JSON.stringify(config.rawSettings) : "";
        }
        function apply(payload: string): string {
            if (!config.dataReady) return "Configuration is not ready";
            try {
                let data = JSON.parse(payload);
                if (!data || typeof data !== "object" || Array.isArray(data)) return "Invalid settings";
                for (let key of ["theme", "bar", "dock"]) {
                    if (!data[key] || typeof data[key] !== "object" || Array.isArray(data[key])) return "Invalid " + key;
                }
                let updates = {theme: data.theme, bar: data.bar, dock: data.dock};
                // Theme-owned visual preferences. Security, device configuration,
                // notification sounds and application commands remain untouched.
                let visualKeys = {
                    launcher: ["position", "width", "itemCount"],
                    osd: ["horizontalPosition", "verticalPosition", "orientation", "showCapsLock", "showNumLock", "showAirplane", "attachToBar"],
                    notifications: ["position", "horizontalPosition", "verticalPosition", "showEmptyGraphic"],
                    lockscreen: ["backgroundMode", "customBackground"]
                };
                let visual = data.__visual || {};
                for (let section of Object.keys(visual)) {
                    if (!visualKeys[section] || !visual[section] || typeof visual[section] !== "object") return "Invalid visual section";
                    let current = JSON.parse(JSON.stringify(config.rawSettings[section] || {}));
                    for (let field of Object.keys(visual[section])) {
                        if (!visualKeys[section].includes(field)) return "Invalid visual field";
                        if (visual[section][field] === null) delete current[field];
                        else current[field] = visual[section][field];
                    }
                    updates[section] = current;
                }
                config.updateJsonBulk(updates);
                return "ok";
            } catch (e) {
                return "Invalid settings: " + e;
            }
        }
    }

    Component.onCompleted: {
        if (settingsWatcher.path) {
            settingsWatcher.reload();
        }
    }

    Component.onDestruction: {
        let targetObj = pendingPayload !== null ? pendingPayload : rawSettings;
        let str = JSON.stringify(targetObj, null, 2);
        lastWrittenContent = str;
        Quickshell.execDetached(["bash", "-c", writerScript, "_", settingsJsonPath, str + "\n"]);
    }
}
