import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Qt.labs.folderlistmodel
import QtMultimedia
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../"
import "../reusables"

Item {
    id: window
    // local offline wallpaper picker v1
    visible: false
    width: Screen.width
    focus: true

    function s(val) {
        return Scaler.s(val) * 1.12;
    }

    // local reliable wallpaper refresh v3
    readonly property string scriptDir: (Caching.serpantinumDir || (Quickshell.env("HOME") + "/.local/share/serpantinum/src")) + "/scripts/wallpaper"

    property string widgetArg: ""
    property string targetWallName: ""
    property bool initialFocusSet: false
    property int visibleItemCount: -1
    property int scrollAccum: 0
    property real scrollThreshold: window.s(45)

    property string currentFilter: "All"
    property string _lastFilter: "All"
    property var colorMap: ({})
    property var bucketMap: ({})
    property var thumbLookup: ({})
    property var srcNameLookup: ({})
    property int cacheVersion: 0


    property bool isApplying: false
    property bool isMonitorSelectorOpen: false
    property bool allowAddAnimation: false

    property bool isAnchorScrolling: false
    property bool _silentFilterChange: false
    property bool _refreshedForDisplay: false
    property string _lastFilterApplied: ""
    property int _lastProxyVersion: -1
    property bool indexRequested: false

    property var configSettings: Config.rawSettings
    function libraryRoot(path) {
        let clean = String(path).replace(/\/+$/, "");
        return clean.replace(/\/Wallpapers\/(Pictures|Videos)$/, "/Wallpapers");
    }
    property string srcDir: {
        let dummy = configSettings;
        return libraryRoot(Config.getSetting("wallpaperDir", "") || Config.getSetting("wallpaper_dir", "") || Quickshell.env("WALLPAPER_DIR") || (Quickshell.env("HOME") + "/Pictures/Wallpapers"));
    }
    readonly property string pictureDir: window.srcDir + "/Pictures"
    readonly property string videoDir: window.srcDir + "/Videos"

    onSrcDirChanged: {
        window.initialFocusSet = false;
        window.syncFromSrcModel();
        window.triggerIndexer();
        libraryWatcherRestart.restart();
    }

    Connections {
        target: Config
        function onSettingsLoaded() {
            let dir = window.libraryRoot(Config.getSetting("wallpaperDir", "") || Config.getSetting("wallpaper_dir", "") || Quickshell.env("WALLPAPER_DIR") || (Quickshell.env("HOME") + "/Pictures/Wallpapers"));
            if (dir && dir !== window.srcDir) {
                window.srcDir = dir;
            }
        }
    }

    Timer {
        id: focusTimer
        interval: 50
        repeat: false
        onTriggered: {
            view.forceActiveFocus();
        }
    }

    Timer {
        id: anchorScrollTimer
        interval: 450
        onTriggered: window.isAnchorScrolling = false
    }

    // Thumbnails are independent from the wallpaper originals and desktop selection.
    property var previewThumbnails: ({})
    property var nearbyPreviewSources: []

    function requestPreviewThumbnails() {
        if (!window.visible || displayModel.count === 0) return;
        let center = Math.max(0, view.currentIndex);
        let sources = [];
        function add(index) {
            if (index < 0 || index >= displayModel.count) return;
            let item = displayModel.get(index);
            let source = String(item.isVideo ? (item.posterUrl || "") : (item.fileUrl || ""));
            if (source !== "" && sources.indexOf(source) < 0) sources.push(source);
        }
        add(center);
        for (let distance = 1; distance <= 20; distance++) {
            add(center + distance);
            add(center - distance);
        }
        window.nearbyPreviewSources = sources.slice(0, 5);
        if (previewThumbProcess.running) previewThumbProcess.write(JSON.stringify(sources) + "\n");
    }

    Timer {
        id: previewRequestTimer
        interval: 75
        onTriggered: window.requestPreviewThumbnails()
    }

    Connections {
        target: displayModel
        function onCountChanged() { previewRequestTimer.restart(); }
    }

    Process {
        id: previewThumbProcess
        running: window.visible
        stdinEnabled: true
        command: ["python3", window.scriptDir + "/picker_thumbnails.py", "--cache-dir", Caching.getCacheDir("wallpaper") + "/picker-previews"]
        onStarted: previewRequestTimer.restart()
        stdout: SplitParser {
            onRead: line => {
                try {
                    let result = JSON.parse(line);
                    if (result.source && result.thumbnail) {
                        let updated = Object.assign({}, window.previewThumbnails);
                        updated[result.source] = result.thumbnail;
                        window.previewThumbnails = updated;
                    }
                } catch (error) { console.warn("Wallpaper preview response:", error); }
            }
        }
    }

    // Prime Qt's shared image cache for the selection and its nearest neighbors.
    Repeater {
        model: window.visible ? window.nearbyPreviewSources : []
        delegate: Image {
            required property string modelData
            visible: false
            source: window.previewThumbnails[modelData] || modelData
            sourceSize: Qt.size(1280, 720)
            fillMode: Image.PreserveAspectCrop
            autoTransform: true
            asynchronous: true
            cache: true
        }
    }

    readonly property real dynamicCacheBuffer: window.itemWidth * 1.25

    Timer {
        id: applyUnlockTimer
        interval: 150
        onTriggered: window.isApplying = false
    }

    property bool isStartup: srcModel.status === FolderListModel.Loading && localProxyModel.count === 0 && videoProxyModel.count === 0
    property bool isExiting: false
    property bool isReady: visible && !isExiting

    property var exitCallback: null

    function startExit(onFinished) {
        if (isExiting) return;
        isExiting = true;
        exitCallback = onFinished;
        exitAnim.restart();
    }

    SequentialAnimation {
        id: exitAnim
        running: false
        ParallelAnimation {
            NumberAnimation { target: filterBarBackground; property: "anchors.topMargin"; to: window.s(-75); duration: 150; easing.type: Easing.InCubic }
            NumberAnimation { target: filterBarBackground; property: "opacity"; to: 0.0; duration: 160; easing.type: Easing.InQuad }
            NumberAnimation { target: view; property: "opacity"; to: 0.0; duration: 250; easing.type: Easing.InQuad }
            NumberAnimation { target: view; property: "anchors.margins"; to: window.s(45); duration: 250; easing.type: Easing.InCubic }
        }
        ScriptAction {
            script: {
                if (window.exitCallback) {
                    let cb = window.exitCallback;
                    window.exitCallback = null;
                    cb();
                }
            }
        }
    }



    property bool isModelChanging: false

    property bool jumpToLastOnFilterChange: false

    property var historyList: []

    readonly property var filterData: [
        { name: "All", hex: "", label: I18n.t("wallpaper.filters.all") },
        { name: "History", hex: "", label: I18n.t("wallpaper.filters.history") },
        { name: "Video", hex: "", label: I18n.t("wallpaper.filters.vid") },
        { name: "Red", hex: "#FF4500", label: "" },
        { name: "Orange", hex: "#FFA500", label: "" },
        { name: "Yellow", hex: "#FFD700", label: "" },
        { name: "Green", hex: "#32CD32", label: "" },
        { name: "Blue", hex: "#1E90FF", label: "" },
        { name: "Purple", hex: "#8A2BE2", label: "" },
        { name: "Pink", hex: "#FF69B4", label: "" },
        { name: "Monochrome", hex: "#A9A9A9", label: "" }
    ]

    ListModel { id: monitorModel }

    Process {
        id: monitorDetector
        running: false
        command: ["bash", Caching.serpantinumDir + "/scripts/monitors_detect.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n").map(s => s.trim()).filter(s => s.length > 0);
                window.updateMonitorsFromList(lines);
            }
        }
    }

    FileView {
        id: wallpaperHistoryReader
        path: Caching.getCacheDir("wallpaper") + "/history.txt"
        onLoaded: {
            let raw = typeof text === "function" ? text() : text;
            let lines = (raw || "").trim().split("\n").map(s => s.trim()).filter(s => s.length > 0);
            window.historyList = lines;
            if (window.currentFilter === "History") {
                if (!window.reorderHistory()) {
                    window.applyFilters(false);
                }
            }
        }
    }



    Process {
        id: videoSnapshotProcess
        running: false
        property string snapPath: Caching.getCacheDir("wallpaper") + "/current_wallpaper.png"

        onExited: (exitCode) => {
            if (typeof Matugen !== "undefined" && typeof Matugen.generate === "function") {
                Matugen.generate(snapPath);
            }
        }
    }

    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (window.visible) {
                window.loadMonitors();
            }
        }
    }

    Component {
        id: previewPlayerComponent
        MediaPlayer {
            audioOutput: AudioOutput { muted: true }
            loops: MediaPlayer.Infinite
        }
    }

    property var globalPreviewPlayer: null
    readonly property bool previewPlaying: !!globalPreviewPlayer && globalPreviewPlayer.playbackState === MediaPlayer.PlayingState

    function ensurePreviewPlayer() {
        if (!globalPreviewPlayer) globalPreviewPlayer = previewPlayerComponent.createObject(window);
        return globalPreviewPlayer;
    }

    function resetPreviewPlayer() {
        if (!globalPreviewPlayer) return;
        if (globalPreviewPlayer.playbackState === MediaPlayer.PlayingState) {
            globalPreviewPlayer.stop();
        }
        globalPreviewPlayer.source = "";
        globalPreviewPlayer.videoOutput = null;
    }

    Process {
        id: wallpaperMonitorTracker
        running: false
        command: [
            "bash",
            "-c",
            "cat '" + Caching.getCacheDir("wallpaper") + "/current_" + (masterWindow.screen ? masterWindow.screen.name : "") + "_name' 2>/dev/null || cat '" + Caching.getCacheDir("wallpaper") + "/current_default_name' 2>/dev/null || echo ''"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let activeWallpaper = this.text.trim();
                if (!activeWallpaper) {
                    let scName = masterWindow.screen ? masterWindow.screen.name : "";
                    activeWallpaper = Wallpaper.getWallpaper(scName);
                }

                let newTarget = (window.widgetArg !== "") ? window.widgetArg : (activeWallpaper !== "" ? activeWallpaper : window.targetWallName);
                let targetChanged = (newTarget !== window.targetWallName);
                if (newTarget !== "") {
                    window.targetWallName = newTarget;
                }
                if (targetChanged || !window.initialFocusSet) {
                    window.initialFocusSet = false;
                    window.selectCurrentWallpaperTabAndFocus();
                }
            }
        }
    }

    function getCleanBaseName(name) {
        if (!name) return "";
        let clean = String(name);
        let slash = clean.lastIndexOf("/");
        if (slash !== -1) clean = clean.substring(slash + 1);
        if (clean.startsWith("000_")) clean = clean.substring(4);
        clean = clean.replace(/\.(jpg|jpeg|png|webp|gif|bmp|mp4|mkv|mov|webm)$/i, "");
        return clean;
    }

    function getCleanName(name) {
        if (!name) return "";
        let clean = String(name);
        let slash = clean.lastIndexOf("/");
        if (slash !== -1) clean = clean.substring(slash + 1);
        return clean.startsWith("000_") ? clean.substring(4) : clean;
    }

    function getOriginalFileName(safeFileName) {
        if (!safeFileName) return "";
        let s = String(safeFileName);
        let slash = s.lastIndexOf("/");
        if (slash !== -1) s = s.substring(slash + 1);
        if (window.srcNameLookup[s]) return window.srcNameLookup[s];
        let clean = window.getCleanName(s);
        if (window.srcNameLookup[clean]) return window.srcNameLookup[clean];
        let base = window.getCleanBaseName(s);
        if (window.srcNameLookup[base]) return window.srcNameLookup[base];
        return clean;
    }

    function isVideoTarget(name) {
        if (!name) return false;
        let s = String(name).toLowerCase();
        let slash = s.lastIndexOf("/");
        if (slash !== -1) s = s.substring(slash + 1);
        if (s.startsWith("000_")) return true;
        if (s.endsWith(".mp4") || s.endsWith(".mkv") || s.endsWith(".mov") || s.endsWith(".webm")) return true;
        let orig = window.getOriginalFileName(name).toLowerCase();
        if (orig.endsWith(".mp4") || orig.endsWith(".mkv") || orig.endsWith(".mov") || orig.endsWith(".webm")) return true;
        let base = window.getCleanBaseName(name);
        let match = window.thumbLookup[base] || window.thumbLookup[s];
        if (match && match.isVideo) return true;
        return false;
    }



    function loadMonitors() {
        monitorDetector.running = false;
        monitorDetector.running = true;
    }

    function updateMonitorsFromList(screenNames) {
        let selectionState = {};
        for (let i = 0; i < monitorModel.count; i++) {
            let item = monitorModel.get(i);
            selectionState[item.name] = item.selected;
        }

        monitorModel.clear();

        for (let i = 0; i < screenNames.length; i++) {
            let screenName = screenNames[i];
            if (!screenName) continue;

            let isSelected = selectionState.hasOwnProperty(screenName)
                ? selectionState[screenName]
                : true;

            monitorModel.append({
                "name": screenName,
                "selected": isSelected
            });
        }
    }

    function getMonitorOutputs() {
        if (monitorModel.count <= 1) return "all";

        let selected = [];
        for (let i = 0; i < monitorModel.count; i++) {
            if (monitorModel.get(i).selected) {
                selected.push(monitorModel.get(i).name);
            }
        }

        if (selected.length === 0) return "none";
        if (selected.length === monitorModel.count) return "all";

        return selected.join(",");
    }

    function setWallpaperOnMonitors(targetFile, transition) {
        let outputs = window.getMonitorOutputs();
        if (outputs === "none") return;

        if (outputs === "all") {
            Wallpaper.setWallpaper("all", targetFile, transition);
        } else {
            let monArr = outputs.split(",");
            for (let i = 0; i < monArr.length; i++) {
                Wallpaper.setWallpaper(monArr[i], targetFile, transition);
            }
        }
    }

    function reorderHistory() {
        if (window.currentFilter !== "History" || displayModel.count === 0 || !window.targetWallName) {
            return false;
        }

        let cleanTarget = window.getCleanBaseName(window.targetWallName);
        let fullTarget = window.getCleanName(window.targetWallName);
        let foundIdx = -1;

        for (let i = 0; i < displayModel.count; i++) {
            let fn = displayModel.get(i).fileName;
            if (fn === window.targetWallName || window.getCleanName(fn) === fullTarget || window.getCleanBaseName(fn) === cleanTarget) {
                foundIdx = i;
                break;
            }
        }

        if (foundIdx === -1) {
            return false;
        }

        if (foundIdx === 0) {
            view.currentIndex = 0;
            return true;
        }

        let histItems = window.getHistoryItems();
        if (histItems.length !== displayModel.count) {
            return false;
        }

        let displaySet = {};
        for (let i = 0; i < displayModel.count; i++) {
            displaySet[displayModel.get(i).fileName] = true;
        }
        for (let i = 0; i < histItems.length; i++) {
            if (!displaySet[histItems[i].fileName]) {
                return false;
            }
        }

        displayModel.move(foundIdx, 0, 1);
        view.currentIndex = 0;
        return true;
    }

    function applyWallpaper(safeFileName, isVideo) {
        if (!safeFileName || window.isApplying) return;

        let outputs = window.getMonitorOutputs();
        if (outputs === "none") return;

        window.isApplying = true;
        applyUnlockTimer.restart();

        window.targetWallName = safeFileName;
        let realFileName = window.getOriginalFileName(safeFileName);

        const transitionTypes = ["fade"];
        const randomTransition = transitionTypes[Math.floor(Math.random() * transitionTypes.length)];

        if (window.currentFilter === "History") {
            window.reorderHistory();
        }

        wallpaperHistoryReader.reload();



        let lookup = window.thumbLookup[safeFileName] || window.thumbLookup[window.getCleanBaseName(safeFileName)] || {};
        let finalPath = lookup.filePath || ((isVideo || window.isVideoTarget(safeFileName) ? window.videoDir : window.pictureDir) + "/" + realFileName);
        let posterPath = lookup.posterPath || "";

        window.setWallpaperOnMonitors(finalPath, randomTransition);

        let isVid = isVideo || window.isVideoTarget(safeFileName) || finalPath.toLowerCase().match(/\.(mp4|mkv|mov|webm)$/) !== null;

        if (isVid) {
            if (posterPath && posterPath !== "") {
                if (typeof Matugen !== "undefined" && typeof Matugen.generate === "function") {
                    Matugen.generate(posterPath);
                }
            } else {
                let snap = Caching.getCacheDir("wallpaper") + "/current_wallpaper.png";
                videoSnapshotProcess.command = [
                    "bash", "-c",
                    "ffmpeg -y -hide_banner -loglevel error -ss 0.5 -i \"$1\" -frames:v 1 -q:v 2 \"$2\" 2>/dev/null || ffmpeg -y -hide_banner -loglevel error -i \"$1\" -frames:v 1 -q:v 2 \"$2\" 2>/dev/null",
                    "_",
                    finalPath,
                    snap
                ];
                videoSnapshotProcess.running = true;
            }
        } else {
            if (typeof Matugen !== "undefined" && typeof Matugen.generate === "function") {
                Matugen.generate(finalPath);
            }
        }
    }





    function selectCurrentWallpaperTabAndFocus() {
        if (!window.targetWallName) {
            window.applyFilters(true);
            return;
        }

        let isVid = window.isVideoTarget(window.targetWallName);
        if (isVid) {
            if (window.currentFilter !== "Video") {
                window._silentFilterChange = true;
                window.currentFilter = "Video";
                window._silentFilterChange = false;
            }
        } else {
            if (window.currentFilter === "Video") {
                window._silentFilterChange = true;
                window.currentFilter = "All";
                window._silentFilterChange = false;
            } else if (window.currentFilter !== "All" && window.currentFilter !== "History") {
                let b = window.bucketMap[window.targetWallName] || window.bucketMap[window.getCleanName(window.targetWallName)] || window.bucketMap[window.getCleanBaseName(window.targetWallName)] || "";
                if (b && b !== window.currentFilter) {
                    window._silentFilterChange = true;
                    window.currentFilter = "All";
                    window._silentFilterChange = false;
                }
            }
        }
        window.applyFilters(true);
    }

    function refreshForDisplay() {
        window.triggerIndexer();
        window._refreshedForDisplay = true;
        if (!window.targetWallName) {
            let screenName = masterWindow.screen ? masterWindow.screen.name : "";
            let current = (typeof Wallpaper !== "undefined") ? Wallpaper.getWallpaper(screenName) : "";
            if (current) window.targetWallName = current;
        }
        window.initialFocusSet = false;
        wallpaperMonitorTracker.running = false;
        wallpaperMonitorTracker.running = true;
        wallpaperHistoryReader.reload();
        window.isFilterAnimating = true;
        filterAnimationTimer.restart();
        if (displayModel.count === 0) window.syncFromSrcModel();
        window.selectCurrentWallpaperTabAndFocus();
    }

    onVisibleChanged: {
        if (!visible) {
            window._refreshedForDisplay = false;
            window.isExiting = false;
            exitAnim.stop();
            window.initialFocusSet = false;
            window.allowAddAnimation = false;
            window.isApplying = false;
            window.isMonitorSelectorOpen = false;
            window.resetPreviewPlayer();
        } else {
            window.isExiting = false;
            exitAnim.stop();
            window.triggerIndexer();
            window.loadMonitors();
            if (!window._refreshedForDisplay) window.refreshForDisplay();
            else if (displayModel.count > 0 && view.currentIndex >= 0) view.positionViewAtIndex(view.currentIndex, ListView.Center);
            focusTimer.restart();
        }
    }

    property bool isLoading: srcModel.status === FolderListModel.Loading || videoFolderModel.status === FolderListModel.Loading
    property bool showSpinner: window.isLoading
    property string currentNotification: {
        if (isLoading) return I18n.t("wallpaper.notifications.generating_thumbnails");
        if (window.visibleItemCount === 0) return I18n.t("wallpaper.notifications.no_wallpapers_found");
        if (window.currentFilter === "All") return "";
        if (window.currentFilter === "History") return I18n.t("wallpaper.notifications.history");
        if (window.currentFilter === "Video") return I18n.t("wallpaper.notifications.videos");
        return window.currentFilter;
    }

    property bool showNotification: !window.isStartup && currentNotification !== ""

    onWidgetArgChanged: {
        if (widgetArg !== "") {
            targetWallName = widgetArg;
            initialFocusSet = false;
            selectCurrentWallpaperTabAndFocus();
        }
    }

    Timer {
        id: allowAddAnimationTimer
        interval: 300
        onTriggered: window.allowAddAnimation = true
    }



    function updateVisibleCount() {
        window.visibleItemCount = displayModel.count;
    }




    // Larger cover previews with a stable decode size throughout navigation.
    readonly property real itemWidth: Math.max(1, Math.min(window.s(800), width * 0.60, height * 0.63 * 16 / 9))
    readonly property real itemHeight: itemWidth * 9 / 16
    readonly property real borderWidth: window.s(2)
    readonly property real spacing: window.s(12)

    Timer { id: scrollThrottle; interval: 140 }
    property bool isFilterAnimating: false
    Timer { id: filterAnimationTimer; interval: 300; onTriggered: window.isFilterAnimating = false }
    property bool isItemAnimating: false
    Timer { id: itemAnimationTimer; interval: 400; onTriggered: window.isItemAnimating = false }

    function getHistoryItems() {
        let items = [];
        let seen = {};
        
        let listToUse = window.historyList.slice();
        let currentClean = window.getCleanBaseName(window.targetWallName);
        if (currentClean !== "") {
            let existingIdx = -1;
            for (let k = 0; k < listToUse.length; k++) {
                if (window.getCleanBaseName(listToUse[k]) === currentClean) {
                    existingIdx = k;
                    break;
                }
            }
            if (existingIdx !== -1) {
                listToUse.splice(existingIdx, 1);
            }
            listToUse.unshift(window.targetWallName);
        }

        for (let i = 0; i < listToUse.length; i++) {
            let hName = listToUse[i];
            let cleanH = window.getCleanBaseName(hName);
            if (!cleanH || seen[cleanH]) continue;

            let lookup = window.thumbLookup[cleanH] || window.thumbLookup[hName];
            if (lookup && lookup.fileName && !seen[lookup.fileName]) {
                items.push({
                    "fileName": lookup.fileName,
                    "filePath": lookup.filePath,
                    "fileUrl": String(lookup.fileUrl),
                    "posterPath": lookup.posterPath || "",
                    "posterUrl": String(lookup.posterUrl || ""),
                    "isVideo": !!lookup.isVideo,
                    "hex": lookup.hex || "#808080",
                    "bucket": "History"
                });
                seen[cleanH] = true;
                seen[lookup.fileName] = true;
            }
        }
        return items;
    }

    function syncFromSrcModel() {
        if (!window.visible) return;
        let models = [srcModel, videoFolderModel, rootFolderModel];
        let ready = false;
        for (let model of models) {
            if (!model) continue;
            if (model.status === FolderListModel.Loading) return;
            if (model.status === FolderListModel.Ready) ready = true;
        }
        if (!ready) return;
        let items = [], seen = {};
        for (let model of models) {
            if (!model || model.status !== FolderListModel.Ready) continue;
            for (let i = 0; i < model.count; i++) {
                let name = String(model.get(i, "fileName") || "");
                if (!name || seen[name]) continue;
                seen[name] = true;
                let url = String(model.get(i, "fileUrl"));
                let path = decodeURIComponent(url.replace(/^file:\/\//, ""));
                let cached = window.thumbLookup[name];
                let video = /\.(mp4|mkv|mov|webm)$/i.test(name);
                let item = cached ? Object.assign({}, cached) : {
                    fileName: name, posterPath: "", posterUrl: "", hex: "#808080",
                    bucket: video ? "Video" : "Monochrome"
                };
                item.fileName = name;
                item.filePath = path;
                // Retain the indexer's versioned image URLs until it refreshes.
                item.fileUrl = cached && cached.filePath === path ? cached.fileUrl : url;
                item.isVideo = video;
                if (video) item.bucket = "Video";
                items.push(item);
            }
        }
        window.loadIndexData({items: items});
    }

    FolderListModel {
        id: srcModel
        folder: "file://" + window.pictureDir
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif", "*.bmp", "*.mp4", "*.mkv", "*.mov", "*.webm", "*.JPG", "*.JPEG", "*.PNG", "*.WEBP", "*.GIF", "*.BMP", "*.MP4", "*.MKV", "*.MOV", "*.WEBM"]
        caseSensitive: false
        showDirs: false
        onCountChanged: {
            window.syncFromSrcModel();

            indexerDebounceTimer.restart();
        }
        onStatusChanged: {
            if (status === FolderListModel.Ready) {
                window.syncFromSrcModel();
                indexerDebounceTimer.restart();
            }
        }
    }

    // Keep the video library live when clips are added or removed.
    FolderListModel {
        id: videoFolderModel
        caseSensitive: false
        folder: "file://" + window.videoDir
        nameFilters: ["*.mp4", "*.mkv", "*.mov", "*.webm", "*.MP4", "*.MKV", "*.MOV", "*.WEBM"]
        showDirs: false
        onCountChanged: { window.syncFromSrcModel(); indexerDebounceTimer.restart(); }
        onStatusChanged: if (status === FolderListModel.Ready) { window.syncFromSrcModel(); indexerDebounceTimer.restart(); }
    }

    // Retain support for media stored directly in the library root.
    FolderListModel {
        id: rootFolderModel
        folder: "file://" + window.srcDir
        nameFilters: srcModel.nameFilters
        caseSensitive: false
        showDirs: false
        onCountChanged: { window.syncFromSrcModel(); indexerDebounceTimer.restart(); }
        onStatusChanged: if (status === FolderListModel.Ready) { window.syncFromSrcModel(); indexerDebounceTimer.restart(); }
    }

    Timer {
        id: indexerDebounceTimer
        interval: 150
        repeat: false
        onTriggered: window.triggerIndexer()
    }

    // Metadata watching runs only while the picker is open. Opening always rescans.
    Timer { id: libraryWatcherRestart; interval: 500 }
    Process {
        id: libraryWatcher
        running: window.visible && !libraryWatcherRestart.running
        command: ["python3", window.scriptDir + "/indexer.py", "--watch", window.srcDir]
        stdout: SplitParser {
            onRead: line => {
                try {
                    let change = JSON.parse(line);
                    if (change.srcDir === window.srcDir) window.triggerIndexer();
                } catch (error) { console.warn("Wallpaper watcher response:", error); }
            }
        }
        onExited: if (window.visible && !libraryWatcherRestart.running) libraryWatcherRestart.restart()
    }

    Timer {
        id: indexLaunchTimer
        interval: 0
        onTriggered: {
            if (!window.visible || !window.indexRequested || indexProcess.running) return;
            window.indexRequested = false;
            indexProcess.running = true;
        }
    }
    Timer { id: indexRetryTimer; interval: 500; onTriggered: window.triggerIndexer() }



    Process {
        id: indexDiskReader
        running: false
        command: ["cat", Caching.getCacheDir("wallpaper") + "/current_index.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                let trimmed = this.text ? this.text.trim() : "";
                if (trimmed.length > 0) {
                    try {
                        let data = JSON.parse(trimmed);
                        if (data && data.srcDir === window.srcDir && data.layoutVersion === 2) {
                            window.loadIndexData(data);
                        }
                    } catch(e) {}
                }
            }
        }
    }

    Process {
        id: indexProcess
        running: false
        stderr: StdioCollector {
            onStreamFinished: if (this.text.trim()) console.warn("Wallpaper indexer:", this.text.trim());
        }
        onExited: code => {
            if (code !== 0) { console.warn("Wallpaper indexing exited:", code); window.syncFromSrcModel(); }
            if (window.visible && window.indexRequested) indexLaunchTimer.restart();
        }
        command: [
            "python3",
            window.scriptDir + "/indexer.py",
            window.srcDir,
            Caching.getCacheDir("wallpaper"),
            Caching.getRunDir("wallpaper")
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let trimmed = this.text ? this.text.trim() : "";
                if (trimmed.length > 0) {
                    try {
                        let data = JSON.parse(trimmed);
                        if (data.srcDir === window.srcDir && data.layoutVersion === 2) {
                            window.loadIndexData(data);
                            if (data.indexingPending) indexRetryTimer.restart();
                        }
                    } catch(e) {}
                }
            }
        }
    }

    function triggerIndexer() {
        window.indexRequested = true;
        if (window.visible && !indexProcess.running) indexLaunchTimer.restart();
    }

    function itemsEqualToModel(model, newItems) {
        if (model.count !== newItems.length) return false;
        for (let i = 0; i < newItems.length; i++) {
            let e = model.get(i);
            if (e.fileName !== newItems[i].fileName ||
                e.fileUrl !== newItems[i].fileUrl ||
                e.posterUrl !== newItems[i].posterUrl ||
                e.hex !== newItems[i].hex ||
                e.bucket !== newItems[i].bucket) {
                return false;
            }
        }
        return true;
    }

    function loadIndexData(data) {
        if (!data || !data.items) return;

        let localItems = [];
        let videoItems = [];
        let seen = {};
        let newSrcLookup = {};
        let newThumbLookup = {};
        let newColorMap = {};
        let newBucketMap = {};

        for (let i = 0; i < data.items.length; i++) {
            let item = data.items[i];
            if (!item || !item.fileName) continue;
            let fname = String(item.fileName);
            if (seen[fname]) continue;
            seen[fname] = true;

            let clean = window.getCleanName(fname);
            let base = window.getCleanBaseName(fname);

            newSrcLookup[fname] = fname;
            newSrcLookup[clean] = fname;
            newSrcLookup[base] = fname;

            newThumbLookup[fname] = item;
            newThumbLookup[clean] = item;
            newThumbLookup[base] = item;

            newColorMap[fname] = item.hex || "#808080";
            newBucketMap[fname] = item.bucket || "Monochrome";

            let isVid = !!item.isVideo || window.isVideoTarget(fname) || fname.toLowerCase().match(/\.(mp4|mkv|mov|webm)$/) !== null;

            if (isVid) {
                item.isVideo = true;
                item.bucket = "Video";
                videoItems.push(item);
            } else {
                item.isVideo = false;
                localItems.push(item);
            }
        }

        const order = { "Red": 1, "Orange": 2, "Yellow": 3, "Green": 4, "Blue": 5, "Purple": 6, "Pink": 7, "Monochrome": 8 };
        localItems.sort((a, b) => {
            let oA = order[a.bucket] || 10;
            let oB = order[b.bucket] || 10;
            if (oA !== oB) return oA - oB;
            return String(a.fileName).localeCompare(String(b.fileName));
        });
        videoItems.sort((a, b) => String(a.fileName).localeCompare(String(b.fileName)));

        let localChanged = !window.itemsEqualToModel(localProxyModel, localItems);
        let videoChanged = !window.itemsEqualToModel(videoProxyModel, videoItems);

        if (!localChanged && !videoChanged) return;

        window.srcNameLookup = newSrcLookup;
        window.thumbLookup = newThumbLookup;
        window.colorMap = newColorMap;
        window.bucketMap = newBucketMap;
        window.cacheVersion++;

        window.isModelChanging = true;
        let wasAllowing = window.allowAddAnimation;
        window.allowAddAnimation = false;

        if (localChanged) {
            localProxyModel.clear();
            if (localItems.length > 0) localProxyModel.append(localItems);
        }
        if (videoChanged) {
            videoProxyModel.clear();
            if (videoItems.length > 0) videoProxyModel.append(videoItems);
        }

        window.selectCurrentWallpaperTabAndFocus();

        if (wasAllowing) allowAddAnimationTimer.restart();
        window.isModelChanging = false;
    }

    function stepToNextValidIndex(direction) {
        if (displayModel.count === 0) return;
        window.initialFocusSet = true;

        let nextIdx = view.currentIndex + direction;
        if (nextIdx >= 0 && nextIdx < displayModel.count) {
            view.currentIndex = nextIdx;
        }
    }

    function cycleFilter(direction) {
        let currentIdx = -1;
        let allFilterNames = window.filterData.map(f => f.name);
        for (let i = 0; i < allFilterNames.length; i++) {
            if (allFilterNames[i] === window.currentFilter) { currentIdx = i; break; }
        }
        if (currentIdx !== -1) {
            let nextIdx = (currentIdx + direction + allFilterNames.length) % allFilterNames.length;
            window.setFilter(allFilterNames[nextIdx]);
        }
    }

    function scrollToAnchor(filter) {
        if (filter === "All") {
            if (displayModel.count > 0) view.currentIndex = 0;
            return;
        }
        for (let i = 0; i < displayModel.count; i++) {
            if (displayModel.get(i).bucket === filter) {
                view.currentIndex = i;
                return;
            }
        }
    }

    function setFilter(newFilter) {
        if (!window.filterData.some(filter => filter.name === newFilter)) return;
        if (window.isApplying || window.currentFilter === newFilter || window._silentFilterChange) return;
        let localModes = ["All", "Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Pink", "Monochrome"];
        let isAnchorSwitch = localModes.indexOf(window.currentFilter) !== -1 && localModes.indexOf(newFilter) !== -1;
        window.allowAddAnimation = false;
        window._lastFilter = window.currentFilter;
        window.currentFilter = newFilter;
        if (newFilter === "History") wallpaperHistoryReader.reload();
        Qt.callLater(() => {
            view.forceActiveFocus();
            if (isAnchorSwitch) {
                window.isAnchorScrolling = true;
                anchorScrollTimer.restart();
                window.scrollToAnchor(newFilter);
            } else {
                window.isModelChanging = true;
                window.isFilterAnimating = true;
                filterAnimationTimer.restart();
                window.applyFilters(true);
                window.isModelChanging = false;
            }
        });
    }

    function applyFilters(forceSnap) {
        let sourceModel = window.activeModel;

        window.isModelChanging = true;
        window.resetPreviewPlayer();

        let focusName = window.targetWallName;
        let cleanTarget = window.getCleanBaseName(focusName);
        let fullTarget = window.getCleanName(focusName);

        let localModes = ["All", "Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Pink", "Monochrome"];
        let isLocalMode = localModes.indexOf(window.currentFilter) !== -1;
        let wasLocalMode = localModes.indexOf(window._lastFilterApplied) !== -1;

        let canReuseDisplay = false;
        if (displayModel.count > 0 && window._lastProxyVersion === window.cacheVersion) {
            if (isLocalMode && wasLocalMode) {
                canReuseDisplay = true;
            } else if (window.currentFilter === window._lastFilterApplied && window.currentFilter !== "History") {
                canReuseDisplay = true;
            }
        }

        if (canReuseDisplay) {
            let targetIndex = -1;
            let anchorIndex = -1;

            if (cleanTarget !== "") {
                for (let i = 0; i < displayModel.count; i++) {
                    let it = displayModel.get(i);
                    let fn = it ? (it.fileName || "") : "";
                    if (fn && (fn === focusName || fn === fullTarget || window.getCleanName(fn) === fullTarget || window.getCleanBaseName(fn) === cleanTarget)) {
                        targetIndex = i;
                        break;
                    }
                }
            }

            if (isLocalMode && window.currentFilter !== "All") {
                for (let i = 0; i < displayModel.count; i++) {
                    let it = displayModel.get(i);
                    if (it && it.bucket === window.currentFilter) {
                        anchorIndex = i;
                        break;
                    }
                }
            }

            let indexToFocus = targetIndex !== -1 ? targetIndex : (anchorIndex !== -1 ? anchorIndex : (view.currentIndex >= 0 && view.currentIndex < displayModel.count ? view.currentIndex : 0));
            window.jumpToLastOnFilterChange = false;

            if (indexToFocus !== -1 && displayModel.count > 0) {
                view.currentIndex = indexToFocus;
                if (forceSnap) {
                    view.positionViewAtIndex(indexToFocus, ListView.Center);
                }

                if (targetIndex !== -1 || cleanTarget === "") {
                    window.initialFocusSet = true;
                }

                if (indexToFocus >= 0 && indexToFocus < displayModel.count && isLocalMode) {
                    let bucket = displayModel.get(indexToFocus).bucket || "All";
                    if (indexToFocus === 0) bucket = "All";
                    if (window.currentFilter !== bucket && localModes.indexOf(bucket) !== -1) {
                        window._silentFilterChange = true;
                        window.currentFilter = bucket;
                        window._silentFilterChange = false;
                    }
                }

                allowAddAnimationTimer.restart();
            }

            window._lastFilterApplied = window.currentFilter;
            window.isModelChanging = false;
            return;
        }

        let newItems = [];
        let seenNames = {};
        let firstValidIndex = -1;
        let lastValidIndex = -1;
        let targetIndex = -1;
        let anchorIndex = -1;

        if (isLocalMode) {
            for (let i = 0; i < localProxyModel.count; i++) {
                let it = localProxyModel.get(i);
                if (!it || !it.fileName) continue;
                let fname = it.fileName;
                if (seenNames[fname]) continue;
                seenNames[fname] = true;

                let bucket = it.bucket || "Monochrome";
                newItems.push({
                    "fileName": fname,
                    "filePath": it.filePath || "",
                    "fileUrl": String(it.fileUrl),
                    "posterPath": it.posterPath || "",
                    "posterUrl": String(it.posterUrl || ""),
                    "isVideo": false,
                    "hex": it.hex || "#808080",
                    "bucket": bucket
                });

                let currentIndex = newItems.length - 1;
                if (firstValidIndex === -1) firstValidIndex = currentIndex;
                lastValidIndex = currentIndex;

                if (targetIndex === -1 && cleanTarget !== "") {
                    if (fname === focusName || fname === fullTarget || window.getCleanName(fname) === fullTarget || window.getCleanBaseName(fname) === cleanTarget) {
                        targetIndex = currentIndex;
                    }
                }

                if (anchorIndex === -1 && bucket === window.currentFilter) {
                    anchorIndex = currentIndex;
                }
            }
        } else if (window.currentFilter === "History") {
            let histItems = window.getHistoryItems();
            for (let h = 0; h < histItems.length; h++) {
                let fname = histItems[h].fileName;
                if (!fname || seenNames[fname]) continue;
                seenNames[fname] = true;

                newItems.push({
                    "fileName": fname,
                    "filePath": histItems[h].filePath || "",
                    "fileUrl": histItems[h].fileUrl,
                    "posterPath": histItems[h].posterPath || "",
                    "posterUrl": histItems[h].posterUrl || "",
                    "isVideo": !!histItems[h].isVideo,
                    "hex": histItems[h].hex || "#808080",
                    "bucket": "History"
                });

                let currentIndex = newItems.length - 1;
                if (firstValidIndex === -1) firstValidIndex = currentIndex;
                lastValidIndex = currentIndex;

                if (targetIndex === -1 && cleanTarget !== "") {
                    if (fname === focusName || fname === fullTarget || window.getCleanName(fname) === fullTarget || window.getCleanBaseName(fname) === cleanTarget) {
                        targetIndex = currentIndex;
                    }
                }
            }
        } else if (window.currentFilter === "Video") {
            if (sourceModel && sourceModel.count > 0) {
                for (let i = 0; i < sourceModel.count; i++) {
                    let it = sourceModel.get(i);
                    let fname = it ? (it.fileName || "") : "";
                    if (!fname || seenNames[fname]) continue;
                    seenNames[fname] = true;

                    newItems.push({
                        "fileName": fname,
                        "filePath": it.filePath || "",
                        "fileUrl": String(it.fileUrl),
                        "posterPath": it.posterPath || "",
                        "posterUrl": String(it.posterUrl || ""),
                        "isVideo": !!it.isVideo,
                        "hex": it.hex || "#808080",
                        "bucket": window.currentFilter
                    });

                    let currentIndex = newItems.length - 1;
                    if (firstValidIndex === -1) firstValidIndex = currentIndex;
                    lastValidIndex = currentIndex;

                    if (targetIndex === -1 && cleanTarget !== "") {
                        if (fname === focusName || fname === fullTarget || window.getCleanName(fname) === fullTarget || window.getCleanBaseName(fname) === cleanTarget) {
                            targetIndex = currentIndex;
                        }
                    }
                }
            }
        }

        let isIdentical = (displayModel.count === newItems.length);
        if (isIdentical && newItems.length > 0) {
            let mid = Math.floor(newItems.length / 2);
            let last = newItems.length - 1;
            let d0 = displayModel.get(0);
            let dMid = displayModel.get(mid);
            let dLast = displayModel.get(last);
            if (!d0 || !dMid || !dLast ||
                d0.fileName !== newItems[0].fileName ||
                d0.posterUrl !== newItems[0].posterUrl ||
                dMid.fileName !== newItems[mid].fileName ||
                dLast.fileName !== newItems[last].fileName) {
                isIdentical = false;
            } else {
                for (let i = 0; i < newItems.length; i++) {
                    let d = displayModel.get(i);
                    if (!d ||
                        d.fileName !== newItems[i].fileName ||
                        d.fileUrl !== newItems[i].fileUrl ||
                        d.posterUrl !== newItems[i].posterUrl ||
                        d.bucket !== newItems[i].bucket) {
                        isIdentical = false;
                        break;
                    }
                }
            }
        }

        if (!isIdentical) {
            displayModel.clear();
            if (newItems.length > 0) {
                displayModel.append(newItems);
            }
            window.updateVisibleCount();
        }

        window._lastFilterApplied = window.currentFilter;
        window._lastProxyVersion = window.cacheVersion;

        let indexToFocus = targetIndex !== -1 ? targetIndex : (window.jumpToLastOnFilterChange && lastValidIndex !== -1 ? lastValidIndex : (displayModel.count > 0 ? (view.currentIndex >= 0 && view.currentIndex < displayModel.count ? view.currentIndex : 0) : -1));
        window.jumpToLastOnFilterChange = false;

        if (localModes.indexOf(window.currentFilter) !== -1 && anchorIndex !== -1 && targetIndex === -1 && forceSnap) {
             indexToFocus = anchorIndex;
        }

        if (indexToFocus !== -1 && displayModel.count > 0) {
            view.currentIndex = indexToFocus;
            if (forceSnap) {
                if (!isIdentical) {
                    view.forceLayout();
                }
                view.positionViewAtIndex(indexToFocus, ListView.Center);
            }

            if (targetIndex !== -1 || cleanTarget === "") {
                window.initialFocusSet = true;
            }

            if (indexToFocus >= 0 && indexToFocus < displayModel.count && localModes.indexOf(window.currentFilter) !== -1) {
                let bucket = displayModel.get(indexToFocus).bucket || "All";
                if (indexToFocus === 0) bucket = "All";
                if (window.currentFilter !== bucket && localModes.indexOf(bucket) !== -1) {
                    window._silentFilterChange = true;
                    window.currentFilter = bucket;
                    window._silentFilterChange = false;
                }
            }

            allowAddAnimationTimer.restart();
        }

        window.isModelChanging = false;
    }

    Shortcut { sequence: "Left"; enabled: window.visible && !window.isApplying; onActivated: window.stepToNextValidIndex(-1) }
    Shortcut { sequence: "Right"; enabled: window.visible && !window.isApplying; onActivated: window.stepToNextValidIndex(1) }
    Shortcut {
        sequence: "Return"
        enabled: window.visible && !window.isApplying
        onActivated: {
            if (view.currentIndex >= 0 && view.currentIndex < displayModel.count) {
                let item = displayModel.get(view.currentIndex);
                if (item && item.fileName) window.applyWallpaper(String(item.fileName), !!item.isVideo);
            }
        }
    }
    Shortcut { sequence: "Tab"; enabled: window.visible && !window.isApplying; onActivated: window.cycleFilter(1) }
    Shortcut { sequence: "Backtab"; enabled: window.visible && !window.isApplying; onActivated: window.cycleFilter(-1) }

    ListModel { id: localProxyModel }
    ListModel { id: videoProxyModel }

    ListModel { id: displayModel }
    readonly property var activeModel: window.currentFilter === "Video" ? videoProxyModel : localProxyModel





    ListView {
        id: view
        anchors.fill: parent
        opacity: window.isReady ? 1.0 : 0.0
        anchors.margins: window.isReady ? 0 : window.s(40)
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        Behavior on anchors.margins { NumberAnimation { duration: 650; easing.type: Easing.OutQuint } }

        spacing: window.spacing; orientation: ListView.Horizontal; clip: true
        interactive: !window.isApplying
        cacheBuffer: window.dynamicCacheBuffer
        reuseItems: false

        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: (width - window.itemWidth) / 2
        preferredHighlightEnd: (width + window.itemWidth) / 2

        highlightMoveDuration: (window.isFilterAnimating || window.isModelChanging) ? 0 : 460
        highlightResizeDuration: 460
        focus: true

        onCurrentIndexChanged: {
            previewRequestTimer.restart();
            window.isItemAnimating = true; itemAnimationTimer.restart();


                let localModes = ["All", "Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Pink", "Monochrome"];
                if (!window.isModelChanging && !window.isFilterAnimating && !window.isAnchorScrolling && localModes.indexOf(window.currentFilter) !== -1) {
                    if (currentIndex >= 0 && currentIndex < displayModel.count) {
                        let bucket = displayModel.get(currentIndex).bucket || "All";
                        if (currentIndex === 0) bucket = "All";
                        if (window.currentFilter !== bucket && localModes.indexOf(bucket) !== -1) {
                            window._silentFilterChange = true;
                            window.currentFilter = bucket;
                            window._silentFilterChange = false;
                        }
                    }
                }
            
        }

        add: Transition {
            enabled: window.allowAddAnimation && !window.isModelChanging && !window.isFilterAnimating
            NumberAnimation { properties: "x,y"; duration: 400; easing.type: Easing.OutCubic }
        }
        addDisplaced: Transition {
            enabled: window.allowAddAnimation && !window.isModelChanging && !window.isFilterAnimating
            NumberAnimation { properties: "x,y"; duration: 400; easing.type: Easing.OutCubic }
        }
        move: Transition {
            enabled: !window.isModelChanging && !window.isFilterAnimating
            NumberAnimation { properties: "x,y"; duration: 400; easing.type: Easing.OutCubic }
        }
        moveDisplaced: Transition {
            enabled: !window.isModelChanging && !window.isFilterAnimating
            NumberAnimation { properties: "x,y"; duration: 400; easing.type: Easing.OutCubic }
        }
        remove: Transition {
            enabled: window.allowAddAnimation && !window.isModelChanging && !window.isFilterAnimating
            NumberAnimation { properties: "x,y"; duration: 400; easing.type: Easing.OutCubic }
        }
        removeDisplaced: Transition {
            enabled: window.allowAddAnimation && !window.isModelChanging && !window.isFilterAnimating
            NumberAnimation { properties: "x,y"; duration: 400; easing.type: Easing.OutCubic }
        }
        displaced: Transition {
            enabled: window.allowAddAnimation && !window.isModelChanging && !window.isFilterAnimating
            NumberAnimation { properties: "x,y"; duration: 400; easing.type: Easing.OutCubic }
        }

        header: Item { width: Math.max(0, (view.width - window.itemWidth) / 2 - view.spacing) }
        footer: Item { width: Math.max(0, (view.width - window.itemWidth) / 2 - view.spacing) }
        model: displayModel

        MouseArea {
            anchors.fill: parent; acceptedButtons: Qt.NoButton
            onWheel: (wheel) => {
                if (window.isApplying || scrollThrottle.running) { wheel.accepted = true; return; }
                let dx = wheel.angleDelta.x; let dy = wheel.angleDelta.y;
                let delta = Math.abs(dx) > Math.abs(dy) ? dx : dy;
                scrollAccum += delta;
                if (Math.abs(scrollAccum) >= scrollThreshold) {
                    window.stepToNextValidIndex(scrollAccum > 0 ? -1 : 1); scrollAccum = 0; scrollThrottle.start();
                }
                wheel.accepted = true;
            }
        }

        delegate: Item {
            id: delegateRoot
            property bool isFailed: false

            function handleFailedImage() {
                if (delegateRoot.isFailed) return;
                delegateRoot.isFailed = true;
                let fn = delegateRoot.safeFileName;
                if (!fn) return;
                for (let i = displayModel.count - 1; i >= 0; i--) {
                    if (displayModel.get(i).fileName === fn) {
                        displayModel.remove(i);
                    }
                }
                window.updateVisibleCount();
                if (view.currentIndex >= displayModel.count) {
                    view.currentIndex = Math.max(0, displayModel.count - 1);
                }

                for (let i = localProxyModel.count - 1; i >= 0; i--) {
                    if (localProxyModel.get(i).fileName === fn) {
                        localProxyModel.remove(i);
                    }
                }
                for (let i = videoProxyModel.count - 1; i >= 0; i--) {
                    if (videoProxyModel.get(i).fileName === fn) {
                        videoProxyModel.remove(i);
                    }
                }
            }

            ListView.onPooled: {
                imageRetryTimer.stop();
                if (delegateRoot.isPlayingVideo || (window.globalPreviewPlayer && previewOutputLoader.item && window.globalPreviewPlayer.videoOutput === previewOutputLoader.item)) {
                    window.resetPreviewPlayer();
                    delegateRoot.isPlayingVideo = false;
                }
            }

            ListView.onReused: {
                delegateRoot.isPlayingVideo = false;
                delegateRoot.isFailed = false;
                paperImage.retryCount = 0;
            }

            readonly property string safeFileName: fileName !== undefined ? String(fileName) : ""
            readonly property string itemFileUrl: fileUrl !== undefined ? String(fileUrl) : ""
            readonly property string itemPosterUrl: posterUrl !== undefined ? String(posterUrl) : ""
            readonly property bool isVideo: (model.isVideo !== undefined && model.isVideo !== null) ? !!model.isVideo : (safeFileName.toLowerCase().match(/\.(mp4|mkv|mov|webm)$/) !== null || safeFileName.startsWith("000_"))

            readonly property bool isCurrent: ListView.isCurrentItem
            readonly property bool isVisuallyEnlarged: isCurrent

            readonly property int dist: Math.abs(index - view.currentIndex)
            readonly property real sideScale: Math.max(0.32, Math.pow(0.70, Math.max(0, dist - 1)))
            readonly property real sideOpacity: isVisuallyEnlarged ? 1.0 : Math.max(0.52, 0.92 - dist * 0.07)
            property real enterOpacity: 0
            Component.onCompleted: enterOpacity = 1
            Behavior on enterOpacity { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
            readonly property real dynamicRadius: window.s(22)
            readonly property real cellWidth: isVisuallyEnlarged ? window.itemWidth : window.itemWidth * 0.25 * sideScale
            readonly property real targetHeight: isVisuallyEnlarged ? window.itemHeight : window.itemHeight * Math.max(0.68, 0.89 - Math.max(0, dist - 1) * 0.055)
            property bool isPlayingVideo: false

            function toggleVideoPlay() {
                if (isPlayingVideo) {
                    window.resetPreviewPlayer();
                    isPlayingVideo = false;
                } else {
                    window.resetPreviewPlayer();
                    let player = window.ensurePreviewPlayer();
                    isPlayingVideo = true;
                    player.videoOutput = previewOutputLoader.item;
                    player.source = delegateRoot.itemFileUrl !== "" ? delegateRoot.itemFileUrl : ("file://" + window.videoDir + "/" + window.getOriginalFileName(delegateRoot.safeFileName));
                    player.play();
                }
            }

            onIsVisuallyEnlargedChanged: {
                if (!isVisuallyEnlarged) {
                    if (window.globalPreviewPlayer && previewOutputLoader.item && window.globalPreviewPlayer.videoOutput === previewOutputLoader.item) {
                        window.resetPreviewPlayer();
                    }
                    isPlayingVideo = false;
                }
            }

            width: isFailed ? 0 : cellWidth
            visible: (opacity > 0.01) && !isFailed
            opacity: isFailed ? 0.0 : sideOpacity * enterOpacity
            height: isFailed ? 0 : targetHeight
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            anchors.verticalCenterOffset: window.s(38)
            z: isVisuallyEnlarged ? 100 : Math.max(1, 50 - dist)

            Behavior on opacity { NumberAnimation { duration: 460; easing.type: Easing.OutCubic } }
            Behavior on width { enabled: window.initialFocusSet && !window.isModelChanging && !window.isFilterAnimating; NumberAnimation { duration: 460; easing.type: Easing.OutCubic } }
            Behavior on height { enabled: window.initialFocusSet && !window.isModelChanging && !window.isFilterAnimating; NumberAnimation { duration: 460; easing.type: Easing.OutCubic } }

            Item {
                id: cardWrapper
                anchors.centerIn: parent
                width: parent.width
                height: parent.height

                MouseArea {
                    anchors.fill: parent; enabled: !window.isApplying && !delegateRoot.isFailed
                    onClicked: { window.initialFocusSet = true; view.currentIndex = index; window.applyWallpaper(delegateRoot.safeFileName, delegateRoot.isVideo); }
                }

                Item {
                    id: paperContentFrame
                    anchors.fill: parent
                    anchors.margins: window.borderWidth

                    Rectangle {
                        anchors.fill: parent
                        radius: delegateRoot.dynamicRadius
                        color: delegateRoot.isFailed ? "transparent" : ThemeBackend.surface0
                    }

                    Rectangle {
                        id: paperMask
                        anchors.fill: parent
                        radius: delegateRoot.dynamicRadius
                        visible: false
                        layer.enabled: true
                    }

                    Item {
                        anchors.fill: parent
                        clip: true
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: paperMask
                        }

                        Image {
                            id: paperImage
                            objectName: "wallpaper-preview"
                            anchors.centerIn: parent ? parent : undefined
                            width: Math.max(1, window.itemWidth - 2 * window.borderWidth)
                            height: Math.max(1, window.itemHeight - 2 * window.borderWidth)
                            fillMode: Image.PreserveAspectCrop
                            readonly property string originalSource: delegateRoot.isVideo ? delegateRoot.itemPosterUrl : delegateRoot.itemFileUrl
                            source: window.previewThumbnails[originalSource] || ((delegateRoot.dist <= 2 || !previewThumbProcess.running) ? originalSource : "")
                            retainWhileLoading: true
                            autoTransform: true
                            smooth: true
                            asynchronous: true
                            cache: true
                            // Never blank a loaded texture while its replacement is decoding.
                            property bool hasShownImage: false
                            opacity: hasShownImage ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                            sourceSize: Qt.size(1280, 720)

                            property int retryCount: 0
                            onStatusChanged: {
                                if (status === Image.Error) {
                                    if (retryCount < 2) {
                                        retryCount++;
                                        imageRetryTimer.restart();
                                    } else {
                                        delegateRoot.handleFailedImage();
                                    }
                                } else if (status === Image.Ready) {
                                    retryCount = 0;
                                    hasShownImage = true;
                                }
                            }
                            Timer {
                                id: imageRetryTimer
                                interval: 300
                                onTriggered: {
                                    if (paperImage.status === Image.Error) {
                                        let currentSrc = paperImage.source;
                                        paperImage.source = "";
                                        paperImage.source = currentSrc;
                                    }
                                }
                            }
                        }

                        Loader {
                            id: previewOutputLoader
                            anchors.centerIn: parent ? parent : undefined
                            width: Math.max(1, window.itemWidth - 2 * window.borderWidth)
                            height: Math.max(1, window.itemHeight - 2 * window.borderWidth)
                            active: delegateRoot.isPlayingVideo
                            visible: delegateRoot.isPlayingVideo && window.previewPlaying
                            sourceComponent: Component {
                                VideoOutput {
                                    fillMode: VideoOutput.PreserveAspectCrop
                                }
                            }
                        }

                        IconButton {
                            glassShadow: 0
                            id: videoActionButton
                            visible: delegateRoot.isVideo
                            anchors.centerIn: parent ? parent : undefined
                            size: window.s(50)
                            cornerRadius: window.s(16)
                            iconFontSize: window.s(20)
                            buttonIcon: delegateRoot.isPlayingVideo && window.previewPlaying ? "󰏤" : "󰐊"
                            accentColor: Qt.rgba(ThemeBackend.surface0.r, ThemeBackend.surface0.g, ThemeBackend.surface0.b, 0.65)
                            textColor: ThemeBackend.text
                            opacity: (delegateRoot.isPlayingVideo && window.previewPlaying) ? (isHoveredOrHighlighted ? 0.9 : 0.18) : 0.88
                            Behavior on opacity { NumberAnimation { duration: 250 } }
                            enabled: !window.isApplying
                            onClicked: delegateRoot.toggleVideoPlay()
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: delegateRoot.dynamicRadius
                        color: "transparent"
                        border.width: delegateRoot.isVisuallyEnlarged ? window.s(2) : window.s(1)
                        border.color: Qt.alpha(ThemeBackend.text, delegateRoot.isVisuallyEnlarged ? 0.78 : 0.14)
                        Behavior on border.color { ColorAnimation { duration: 250 } }
                    }
                }
            }
        }
    }

    Rectangle {
        id: filterBarBackground; anchors.top: parent.top
        anchors.topMargin: window.isReady ? window.s(65) : window.s(-75)
        opacity: window.isReady ? 1.0 : 0.0
        Behavior on anchors.topMargin { NumberAnimation { duration: 650; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        anchors.horizontalCenter: parent.horizontalCenter
        z: 200
        height: window.s(56)
        width: Math.min(window.width - window.s(32), filterRow.implicitWidth + window.s(28))
        radius: window.s(18)
        color: toolbarGlass.active ? "transparent" : Qt.alpha(ThemeBackend.base, Math.min(0.62, ThemeBackend.elementOpacity))
        border.width: 1
        border.color: Qt.alpha(ThemeBackend.text, 0.14)
        readonly property Item glassBackdropItem: filterBackdrop

        WallpaperBlur {
            id: filterBackdrop
            z: -1
            anchors.fill: parent
            radius: parent.radius
        }

        GlassFill {
            id: toolbarGlass
            anchors.fill: parent
            radius: parent.radius
            tintColor: ThemeBackend.base
            tintAmount: 0.34
            frost: 2.2
            rim: 0.32
            shadow: 0
        }

        Flickable {
            id: filterScroll
            anchors.fill: parent
            anchors.leftMargin: window.s(14)
            anchors.rightMargin: window.s(14)
            contentWidth: filterRow.implicitWidth
            contentHeight: height
            clip: true
            interactive: contentWidth > width
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds

        Row {
            id: filterRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: window.s(10)

            Rectangle {
                id: notifDrawer; height: window.s(34)
                property real paddingLeft: window.showSpinner ? window.s(36) : window.s(12)
                property real targetWidth: window.showNotification ? Math.min(notifTextDrawer.implicitWidth + paddingLeft + window.s(16), window.s(300)) : 0
                width: targetWidth; visible: width > 0.1; radius: window.s(10); clip: true; anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                color: Qt.alpha(ThemeBackend.text, 0.06)
                Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 250 } }

                Item {
                    visible: window.showSpinner
                    width: window.s(34)
                    height: window.s(34)
                    anchors.left: parent ? parent.left : undefined
                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

                    LoaderIcon {
                        anchors.centerIn: parent
                        width: window.s(16)
                        height: window.s(16)
                        accentColor: ThemeBackend.text
                        running: window.showSpinner && window.showNotification
                        morphSpeed: 1.2
                    }
                }
                Text {
                    id: notifTextDrawer; anchors.left: parent ? parent.left : undefined; anchors.leftMargin: window.showSpinner ? window.s(36) : window.s(12); anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                    width: Math.min(implicitWidth, window.s(300) - anchors.leftMargin - window.s(12)); text: window.currentNotification; color: ThemeBackend.text; font.family: ThemeBackend.fontFamily; font.pixelSize: window.s(12); font.bold: true; elide: Text.ElideRight
                    opacity: window.showNotification ? 0.9 : 0.0; Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
                    Behavior on anchors.leftMargin { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                }
            }

            Rectangle {
                id: monitorDrawer; visible: monitorModel.count > 1; height: window.s(34)
                property real expandedWidth: window.s(34) + monitorListRow.implicitWidth + window.s(6)
                width: visible ? (window.isMonitorSelectorOpen ? expandedWidth : window.s(34)) : 0
                radius: ThemeBackend.borderRadius; clip: true; anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                color: Qt.alpha(window.isMonitorSelectorOpen ? ThemeBackend.surface2 : ThemeBackend.surface0, ThemeBackend.elementOpacity)
                Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 250 } }

                CanvasIconButton {
                    glassShadow: 0
                    id: monitorToggleBtn
                    size: window.s(34)
                    cornerRadius: window.s(10)
                    iconSize: window.s(14)
                    accentColor: "transparent"
                    bgOpacity: ThemeBackend.elementOpacity
                    textColor: window.isMonitorSelectorOpen ? ThemeBackend.text : ThemeBackend.subtext0
                    anchors.left: parent ? parent.left : undefined
                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                    paintCanvas: function(ctx, canvas) {
                        var s = window.s;
                        ctx.lineWidth = s(2);
                        ctx.strokeStyle = monitorToggleBtn.textColor;
                        ctx.lineJoin = "round";
                        ctx.lineCap = "round";
                        ctx.beginPath(); ctx.rect(s(1), s(2), s(12), s(8)); ctx.stroke();
                        ctx.beginPath(); ctx.moveTo(s(7), s(10)); ctx.lineTo(s(7), s(13)); ctx.moveTo(s(4), s(13)); ctx.lineTo(s(10), s(13)); ctx.stroke();
                    }
                    onClicked: {
                        if (!window.isApplying) {
                            window.isMonitorSelectorOpen = !window.isMonitorSelectorOpen;
                        }
                    }
                }

                Row {
                    id: monitorListRow; anchors.left: monitorToggleBtn.right; anchors.verticalCenter: parent ? parent.verticalCenter : undefined; spacing: window.s(6)
                    opacity: window.isMonitorSelectorOpen ? 1.0 : 0.0; Behavior on opacity { NumberAnimation { duration: 250 } }
                    Repeater {
                        model: monitorModel
                        delegate: ClickButton {
                            height: window.s(26)
                            cornerRadius: window.s(6)
                            horizontalPadding: window.s(8)
                            buttonText: model.name
                            textFontSize: window.s(10)
                            accentColor: model.selected ? ThemeBackend.text : ThemeBackend.surface1
                            bgOpacity: ThemeBackend.elementOpacity
                            textColor: model.selected ? ThemeBackend.base : ThemeBackend.text
                            enabled: window.isMonitorSelectorOpen && !window.isApplying
                            anchors.verticalCenter: parent ? parent.verticalCenter : undefined

                            onClicked: {
                                if (model.selected) {
                                    let activeCount = 0;
                                    for (let i = 0; i < monitorModel.count; i++) { if (monitorModel.get(i).selected) activeCount++; }
                                    if (activeCount > 1) monitorModel.setProperty(index, "selected", false);
                                } else {
                                    monitorModel.setProperty(index, "selected", true);
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                height: window.s(38)
                width: modeRow.implicitWidth + window.s(8)
                anchors.verticalCenter: parent.verticalCenter
                radius: window.s(12)
                color: Qt.alpha(ThemeBackend.text, 0.045)
                border.width: 1
                border.color: Qt.alpha(ThemeBackend.text, 0.07)

                Row {
                    id: modeRow
                    anchors.centerIn: parent
                    spacing: window.s(2)
                    Repeater {
                        model: window.filterData.slice(0, 3)
                        delegate: Rectangle {
                            id: modeButton
                            width: window.s(34)
                            height: window.s(30)
                            radius: window.s(9)
                            readonly property bool selected: window.currentFilter === modelData.name
                            color: Qt.alpha(ThemeBackend.text, selected ? 0.18 : (modeMouse.containsMouse ? 0.08 : 0))
                            border.width: 1
                            border.color: Qt.alpha(ThemeBackend.text, selected ? 0.15 : 0)
                            Behavior on color { ColorAnimation { duration: 160 } }
                            ToolTip.visible: modeMouse.containsMouse
                            ToolTip.text: modelData.label || modelData.name
                            Accessible.role: Accessible.Button
                            Accessible.name: modelData.label || modelData.name
                            Accessible.onPressAction: window.setFilter(modelData.name)
                            Canvas {
                                id: modeIcon
                                anchors.centerIn: parent
                                width: window.s(14)
                                height: window.s(14)
                                property color ink: Qt.alpha(ThemeBackend.text, modeButton.selected ? 1 : 0.70)
                                onInkChanged: requestPaint()
                                onPaint: {
                                    let ctx = getContext("2d");
                                    ctx.reset();
                                    ctx.scale(width / 14, height / 14);
                                    ctx.fillStyle = ink;
                                    ctx.strokeStyle = ink;
                                    ctx.lineWidth = 1.5;
                                    ctx.lineCap = "round";
                                    ctx.lineJoin = "round";
                                    if (modelData.name === "All") {
                                        ctx.fillRect(1,1,5,5); ctx.fillRect(8,1,5,5);
                                        ctx.fillRect(1,8,5,5); ctx.fillRect(8,8,5,5);
                                    } else if (modelData.name === "History") {
                                        ctx.beginPath(); ctx.arc(7,7,5,0,Math.PI*2); ctx.stroke();
                                        ctx.beginPath(); ctx.moveTo(7,4); ctx.lineTo(7,7); ctx.lineTo(10,8); ctx.stroke();
                                    } else {
                                        ctx.beginPath(); ctx.moveTo(3,1); ctx.lineTo(12,7); ctx.lineTo(3,13); ctx.closePath(); ctx.fill();
                                    }
                                }
                            }
                            MouseArea {
                                id: modeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: !window.isApplying
                                onClicked: window.setFilter(modelData.name)
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: 1
                height: window.s(22)
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.alpha(ThemeBackend.text, 0.13)
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: window.s(5)
                Repeater {
                    model: window.filterData.slice(3)
                    delegate: Item {
                        id: swatch
                        width: window.s(30)
                        height: window.s(34)
                        readonly property bool selected: window.currentFilter === modelData.name
                        ToolTip.visible: swatchMouse.containsMouse
                        ToolTip.text: modelData.name
                        Accessible.role: Accessible.Button
                        Accessible.name: modelData.name + " wallpapers"
                        Accessible.onPressAction: window.setFilter(modelData.name)
                        Rectangle {
                            anchors.centerIn: parent
                            width: window.s(29)
                            height: width
                            radius: width / 2
                            color: "transparent"
                            border.width: swatch.selected ? window.s(1.5) : 0
                            border.color: Qt.alpha(ThemeBackend.text, 0.90)
                            scale: swatchMouse.containsMouse ? 1.07 : 1
                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            Rectangle {
                                anchors.centerIn: parent
                                width: window.s(21)
                                height: width
                                radius: width / 2
                                border.width: 1
                                border.color: Qt.alpha("white", 0.22)
                                gradient: Gradient {
                                    GradientStop { position: 0; color: Qt.lighter(modelData.hex, 1.18) }
                                    GradientStop { position: 1; color: Qt.darker(modelData.hex, 1.10) }
                                }
                            }
                        }
                        MouseArea {
                            id: swatchMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !window.isApplying
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.setFilter(modelData.name)
                        }
                    }
                }
            }




        }
        }
    }

    Component.onCompleted: {


        indexDiskReader.running = true;
        window.syncFromSrcModel();
        window.triggerIndexer();

        if (visible) {
            window.loadMonitors();
            window.refreshForDisplay();
            focusTimer.restart();
        }
    }
}
