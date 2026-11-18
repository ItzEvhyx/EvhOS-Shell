pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"
import "IconPackLogic.js" as Logic

Item {
    id: root
    readonly property string sourceDir: Caching.serpantinumDir || (Caching.home + "/.local/share/serpantinum/src")
    readonly property string iconsDir: Caching.home + "/.local/share/icons"
    property var catalog: ({designs:[], aliases:{}, desktop_icons:{}, packs:[]})
    readonly property var packs: catalog.packs || []
    readonly property var lookup: Logic.lookupFor(catalog)
    readonly property string selected: {
        let value = Config.getSetting("theme.iconPack", "EvhOs-Satin");
        return packs.some(pack => pack.id === value) ? value : "EvhOs-Satin";
    }
    readonly property bool pixelated: isPixelated(selected)
    function isPixelated(pack) { return pack === "EvhOs-Pixel-Arcade"; }
    readonly property bool lightBackground: ThemeBackend.base.r * 0.2126 + ThemeBackend.base.g * 0.7152 + ThemeBackend.base.b * 0.0722 > 0.55
    readonly property string effectiveTheme: Logic.effectiveTheme(selected, lightBackground)
    property var syncStatus: ({})
    readonly property string syncError: syncStatus.theme === effectiveTheme ? (syncStatus.error || "") : ""
    readonly property bool syncing: Config.isWriting || (syncStatus.theme === effectiveTheme && !!syncStatus.running)
    property string syncOutput: ""
    property string commandTheme: ""
    property string lastSynced: ""

    function nameFor(id) { return (packs.find(pack => pack.id === String(id || "").replace(/-Light$/, "")) || {}).name || "Satin"; }
    function select(id) {
        if (!packs.some(pack => pack.id === id) || Config.desktopPresetApplying) return;
        Config.setSetting("theme.iconPack", id);
        scheduleSync();
    }
    function sourceForDesign(design, pack, size, light) {
        if (!(catalog.designs || []).includes(design)) return "";
        let chosen = pack || selected;
        let theme = Logic.effectiveTheme(chosen, light === undefined ? lightBackground : light);
        let pixels = chosen === "EvhOs-Type-Density" ? (size <= 32 ? 64 : 128) : size <= 32 ? 32 : size <= 64 ? 64 : 128;
        return Logic.fileUrl(iconsDir + "/" + theme + "/" + pixels + "x" + pixels + "/apps/" + design + ".png");
    }
    function resolveIcon(icon, desktopId, size) {
        // Referencing these properties keeps cached model icons reactive to switches.
        let theme = selected;
        let design = Logic.designFor([desktopId, icon], lookup);
        if (design) return sourceForDesign(design, theme, size || 64);
        let value = String(icon || "");
        if (!value) return "";
        if (/^(file|image|https?):\/\//.test(value)) return value;
        if (value.startsWith("/")) return Logic.fileUrl(value);
        let path = Quickshell.iconPath(value, true) || Quickshell.iconPath(value.replace(/\.(png|svg|xpm|ico)$/i,""), true);
        return path && path.startsWith("/") ? Logic.fileUrl(path) : (path || "");
    }
    function trayIcon(item) {
        let design = Logic.trayDesign(item, lookup);
        return design ? sourceForDesign(design, selected, 64) : "";
    }
    function scheduleSync() { if (!Caching.isStandalone) syncDebounce.restart(); }
    function syncNow() {
        if (Caching.isStandalone || Config.desktopPresetApplying || !Config.dataReady || Config.isWriting || !packs.length || syncProcess.running) return;
        commandTheme = effectiveTheme;
        syncOutput = "";
        syncProcess.command = ["python3", sourceDir + "/scripts/icon-packs.py", "sync", commandTheme];
        syncProcess.running = true;
    }
    onEffectiveThemeChanged: scheduleSync()
    Connections {
        target: Config
        function onDesktopPresetApplyingChanged() { if (!Config.desktopPresetApplying) root.scheduleSync(); }
        function onIsWritingChanged() { if (!Config.isWriting) root.scheduleSync(); }
        function onDataReadyChanged() { if (Config.dataReady) root.scheduleSync(); }
    }
    FileView {
        path: root.sourceDir + "/assets/icon-packs/catalog.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.catalog = JSON.parse(text()); root.scheduleSync(); } catch (error) {} }
    }
    FileView {
        path: Caching.stateDir + "/icon-pack-status.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.syncStatus = JSON.parse(text()); } catch (error) {} }
    }
    Timer { id: syncDebounce; interval: 450; onTriggered: if (root.lastSynced !== root.effectiveTheme || root.syncError) root.syncNow() }
    Process {
        id: syncProcess
        stdout: StdioCollector { onStreamFinished: root.syncOutput = text }
        onExited: function(code) {
            try {
                let result = JSON.parse(root.syncOutput);
                if (code === 0 && result.ok) root.lastSynced = root.commandTheme;
                else root.syncStatus = {theme:root.commandTheme, error:result.error || "Could not update application icons."};
            } catch (error) { root.syncStatus = {theme:root.commandTheme, error:"Could not update application icons."}; }
            if (root.commandTheme !== root.effectiveTheme) root.scheduleSync();
        }
    }
    IpcHandler {
        target: "iconPacks"
        function current(): string { return root.selected; }
        function choose(name: string): string {
            if (!root.packs.some(pack => pack.id === name)) return "Unknown icon pack";
            if (Config.desktopPresetApplying) return "Theme switch in progress";
            root.select(name);
            return "ok";
        }
    }
    Component.onCompleted: scheduleSync()
}
