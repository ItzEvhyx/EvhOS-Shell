import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../reusables"
import "../singletons/widgetcontrols"
import "../"

PanelWindow {
    id: desktopMenuWindow

    screen: DesktopMenuController.screen

    WlrLayershell.namespace: "desktopmenu"
    WlrLayershell.layer: WlrLayer.Bottom
    focusable: desktopMenuWindow.isVisible
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    onIsVisibleChanged: {
        if (isVisible) {
            rootContainer.forceActiveFocus();
            updateNightLightState();
            closeAnim.stop();
            openAnim.restart();
        } else {
            openAnim.stop();
            closeAnim.restart();
        }
    }

    Component.onCompleted: {
        updateNightLightState();
    }

    mask: Region {
        item: (desktopMenuWindow.isVisible || menuContainer.animProgress > 0.001) ? rootContainer : null
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    function s(val) { return (typeof Scaler !== "undefined") ? Scaler.s(val) : val; }

    property bool isVisible: DesktopMenuController.isVisible
    property bool isWidgetMode: DesktopMenuController.mode === "widget"
    property real targetX: DesktopMenuController.targetX
    property real targetY: DesktopMenuController.targetY
    property bool isNightLightActive: false

    property int configRevision: 0

    Connections {
        target: DesktopMenuController

        function onMenuTriggered() {
            rootContainer.forceActiveFocus();
            if (!desktopMenuWindow.isWidgetMode) desktopMenuWindow.refreshWallpaperRing();
            closeAnim.stop();
            openAnim.restart();
        }
    }

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        ignoreUnknownSignals: true
        function onSettingsLoaded() {
            desktopMenuWindow.configRevision++;
            desktopMenuWindow.updateNightLightState();
        }
    }

    Connections {
        target: (typeof BlueLight !== "undefined") ? BlueLight : null
        ignoreUnknownSignals: true
        function onSettingsChanged() {
            desktopMenuWindow.updateNightLightState();
        }
    }

    property real cornerRadius: {
        let dummy = configRevision;
        return (typeof ThemeBackend !== "undefined" && ThemeBackend.borderRadius !== undefined && ThemeBackend.borderRadius !== null)
            ? ThemeBackend.borderRadius
            : s(12);
    }

    property color menuBackgroundColor: {
        if (typeof ThemeBackend !== "undefined" && ThemeBackend.base) {
            return ThemeBackend.base;
        }
        return "#1e1e2e";
    }

    property color buttonColor: {
        if (typeof ThemeBackend !== "undefined" && ThemeBackend.surface0) {
            return ThemeBackend.surface0;
        }
        return "#313244";
    }

    property color primaryButtonColor: {
        if (typeof ThemeBackend !== "undefined" && ThemeBackend.primary) {
            return ThemeBackend.primary;
        }
        if (typeof ThemeBackend !== "undefined" && ThemeBackend.blue) {
            return ThemeBackend.blue;
        }
        return "#89b4fa";
    }

    property color primaryTextColor: {
        if (typeof ThemeBackend !== "undefined" && ThemeBackend.base) {
            return ThemeBackend.base;
        }
        return "#1e1e2e";
    }

    property real menuWidth: s(210)
    property real menuHeight: contentCol.implicitHeight + s(12)
    property real menuOffset: s(3)

    property real rawClampedX: {
        let w = menuWidth;
        let margin = s(8);
        let dockMargin = 0;
        let isDockRight = false;
        let isDockLeft = false;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.dock && Config.rawSettings.dock.enabled !== false) {
            let pos = Config.rawSettings.dock.position || "bottom";
            let sz = s((Config.rawSettings.dock.elementSize || 44) + 20);
            if (pos === "right") { isDockRight = true; dockMargin = sz; }
            else if (pos === "left") { isDockLeft = true; dockMargin = sz; }
        }
        let maxRight = desktopMenuWindow.width - margin - (isDockRight ? dockMargin : 0);
        let minLeft = margin + (isDockLeft ? dockMargin : 0);
        let off = (targetX + w > maxRight) ? -menuOffset : menuOffset;
        if (targetX + w > maxRight) {
            return Math.max(minLeft, targetX - w + off);
        }
        return Math.max(minLeft, Math.min(maxRight - w, targetX + off));
    }

    property real rawClampedY: {
        let h = menuHeight;
        let margin = s(8);
        let dockMargin = 0;
        let isDockBottom = false;
        let isDockTop = false;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.dock && Config.rawSettings.dock.enabled !== false) {
            let pos = Config.rawSettings.dock.position || "bottom";
            let sz = s((Config.rawSettings.dock.elementSize || 44) + 20);
            if (pos === "bottom") { isDockBottom = true; dockMargin = sz; }
            else if (pos === "top") { isDockTop = true; dockMargin = sz; }
        }
        let maxBottom = desktopMenuWindow.height - margin - (isDockBottom ? dockMargin : 0);
        let minTop = margin + (isDockTop ? dockMargin : 0);
        let off = (targetY + h > maxBottom) ? -menuOffset : menuOffset;
        if (targetY + h > maxBottom) {
            return Math.max(minTop, targetY - h + off);
        }
        return Math.max(minTop, Math.min(maxBottom - h, targetY + off));
    }

    // Reserve space for the previews when the menu is near a screen edge.
    readonly property real ringSide: Math.min(s(194), Math.max(0, (width - menuWidth - s(16)) / 2))
    readonly property real ringTop: Math.min(s(121), Math.max(0, (height - menuHeight - s(16)) / 2))
    readonly property real clampedX: isWidgetMode ? rawClampedX : Math.max(ringSide + s(8), Math.min(width - menuWidth - ringSide - s(8), rawClampedX))
    readonly property real clampedY: isWidgetMode ? rawClampedY : Math.max(ringTop + s(8), Math.min(height - menuHeight - ringTop - s(8), rawClampedY))
    property var ringWallpapers: []
    property var favoriteWallpapers: []
    FileView {
        id: favoriteStore
        path: Caching.stateDir + "/wallpaper-ring-favorites.json"
        onLoaded: {
            try { let data = JSON.parse(text()); if (Array.isArray(data)) desktopMenuWindow.favoriteWallpapers = data; } catch (e) {}
        }
    }
    function toggleWallpaperFavorite(path) {
        let favorites = favoriteWallpapers.slice();
        let i = favorites.indexOf(path);
        if (i >= 0) favorites.splice(i, 1); else favorites.push(path);
        favoriteWallpapers = favorites;
        favoriteStore.setText(JSON.stringify(favorites));
    }
    readonly property var ringColors: [
        { name: "Red", color: "#ff4a36" }, { name: "Orange", color: "#ffa500" },
        { name: "Yellow", color: "#ffd700" }, { name: "Green", color: "#32cd32" },
        { name: "Blue", color: "#1e90ff" }, { name: "Purple", color: "#8a2be2" },
        { name: "Pink", color: "#ff69b4" }, { name: "Monochrome", color: "#aaaaaa" }
    ]

    function refreshWallpaperRing() {
        ringWallpapers = [];
        ringIndexReader.running = false;
        ringIndexReader.running = true;
    }

    Process {
        id: ringIndexReader
        command: ["cat", Caching.getCacheDir("wallpaper") + "/current_index.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text);
                    let configuredDir = Config.getSetting("wallpaperDir", "") || Config.getSetting("wallpaper_dir", "") || Quickshell.env("WALLPAPER_DIR") || (Quickshell.env("HOME") + "/Pictures/Wallpapers");
                    if (!data || !Array.isArray(data.items) || data.srcDir !== configuredDir) return;
                    let result = [];
                    for (let i = 0; i < desktopMenuWindow.ringColors.length; i++) {
                        let category = desktopMenuWindow.ringColors[i];
                        let candidates = data.items.filter(item => item && item.bucket === category.name && !item.isVideo && item.filePath && item.fileUrl);
                        if (!candidates.length) continue;
                        let weights = candidates.map(item => desktopMenuWindow.favoriteWallpapers.indexOf(item.filePath) >= 0 ? 4 : 1);
                        let total = weights.reduce((a, b) => a + b, 0);
                        let roll = Math.random() * total;
                        let chosen = candidates[candidates.length - 1];
                        for (let j = 0; j < candidates.length; j++) {
                            roll -= weights[j];
                            if (roll < 0) { chosen = candidates[j]; break; }
                        }
                        result.push({ name: category.name, color: category.color, path: chosen.filePath, url: chosen.fileUrl, thumb: "file://" + Caching.getCacheDir("wallpaper") + "/thumbs/" + chosen.fileName });
                    }
                    desktopMenuWindow.ringWallpapers = result;
                } catch (e) {
                    console.warn("Wallpaper ring: could not read wallpaper index", e);
                }
            }
        }
    }

    function selectRingWallpaper(item) {
        if (!item || !item.path) return;
        DesktopMenuController.isMenuShuffle = false;
        applyWallpaper("all", item.path, "fade");
        if (typeof Matugen !== "undefined" && typeof Matugen.generate === "function") Matugen.generate(item.path);
        DesktopMenuController.hide();
    }

    property bool alignRight: (targetX + menuWidth > desktopMenuWindow.width - s(8))

    visible: isVisible || menuContainer.animProgress > 0.001

    Timer {
        id: reloadTimer
        interval: 50
        repeat: false
        onTriggered: desktopMenuWindow.reloadShell()
    }

    Process {
        id: shuffleProcess
        running: false
        property string targetScreenName: ""
        property real originX: 0.5
        property real originY: 0.5

        stdout: StdioCollector {
            onStreamFinished: {
                let picked = this.text.trim();
                if (picked && picked !== "") {
                    desktopMenuWindow.applyWallpaper(shuffleProcess.targetScreenName, picked, {
                        type: 2,
                        originX: shuffleProcess.originX,
                        originY: shuffleProcess.originY
                    });
                }
            }
        }
    }

    function updateNightLightState() {
        let anyEnabled = false;
        if (typeof BlueLight !== "undefined" && typeof BlueLight.isAnyEnabled === "function") {
            anyEnabled = BlueLight.isAnyEnabled();
        } else if (typeof Config !== "undefined" && typeof Config.getSetting === "function") {
            let ds = Config.getSetting("display", {"monitors": {}});
            let mons = (ds && ds.monitors) ? ds.monitors : {};
            for (let mName in mons) {
                if (mons[mName] && mons[mName].enabled) {
                    anyEnabled = true;
                    break;
                }
            }
        }
        isNightLightActive = anyEnabled;
    }

    function toggleNightLight() {
        if (typeof Sounds !== "undefined" && typeof Sounds.playSfx === "function") {
            Sounds.playSfx("system/quick_click.wav");
        }
        let target = !isNightLightActive;
        isNightLightActive = target;

        let monNames = [];
        let ds = (typeof Config !== "undefined" && typeof Config.getSetting === "function") ? Config.getSetting("display", {"monitors": {}}) : {"monitors": {}};
        let mons = (ds && ds.monitors) ? ds.monitors : {};
        for (let m in mons) {
            if (monNames.indexOf(m) === -1) {
                monNames.push(m);
            }
        }
        if (typeof Quickshell !== "undefined" && Quickshell.screens) {
            for (let i = 0; i < Quickshell.screens.length; i++) {
                let scr = Quickshell.screens[i];
                if (scr && scr.name && monNames.indexOf(scr.name) === -1) {
                    monNames.push(scr.name);
                }
            }
        }

        if (typeof BlueLight !== "undefined" && typeof BlueLight.setEnabled === "function") {
            if (monNames.length > 0) {
                for (let i = 0; i < monNames.length; i++) {
                    BlueLight.setEnabled(monNames[i], target);
                }
            } else {
                BlueLight.setEnabled("", target);
            }
        }
        updateNightLightState();
    }

    function applyWallpaper(scrName, path, transitionData) {
        if (!path) return;
        let mon = scrName || "all";
        let trans = transitionData !== undefined ? transitionData : "fade";

        if (typeof Wallpaper !== "undefined") {
            if (typeof Wallpaper.setWallpaper === "function") {
                Wallpaper.setWallpaper(mon, path, trans);
            } else if (typeof Wallpaper.changeWallpaper === "function") {
                Wallpaper.changeWallpaper(mon, path, trans);
            } else if (typeof Wallpaper.wallpaperChanged === "function") {
                Wallpaper.wallpaperChanged(mon, path, trans);
            }
        }
    }

    function shuffleWallpaper() {
        let scr = desktopMenuWindow.screen || DesktopMenuController.screen;
        let scrName = (scr && scr.name) ? scr.name : "all";
        let cacheDir = (typeof Caching !== "undefined" && typeof Caching.getCacheDir === "function") ? Caching.getCacheDir("wallpaper") : "";
        let stateFile = cacheDir ? (cacheDir + "/current_" + scrName) : "";
        let customDir = "";
        if (typeof Wallpaper !== "undefined") {
            if (Wallpaper.wallpaperDir) customDir = Wallpaper.wallpaperDir;
            else if (Wallpaper.directory) customDir = Wallpaper.directory;
            else if (Wallpaper.folder) customDir = Wallpaper.folder;
        }
        if (!customDir && typeof Config !== "undefined") {
            if (Config.wallpaperDir) customDir = Config.wallpaperDir;
            else if (Config.wallpapersDir) customDir = Config.wallpapersDir;
        }

        let scrW = desktopMenuWindow.width > 0 ? desktopMenuWindow.width : ((scr && scr.geometry && scr.geometry.width) ? scr.geometry.width : 1920);
        let scrH = desktopMenuWindow.height > 0 ? desktopMenuWindow.height : ((scr && scr.geometry && scr.geometry.height) ? scr.geometry.height : 1080);
        let posX = Math.max(desktopMenuWindow.clampedX, Math.min(desktopMenuWindow.clampedX + desktopMenuWindow.menuWidth, desktopMenuWindow.targetX));
        let posY = Math.max(desktopMenuWindow.clampedY, Math.min(desktopMenuWindow.clampedY + desktopMenuWindow.menuHeight, desktopMenuWindow.targetY));
        let normX = scrW > 0 ? Math.max(0.0, Math.min(1.0, posX / scrW)) : 0.5;
        let normY = scrH > 0 ? Math.max(0.0, Math.min(1.0, posY / scrH)) : 0.5;

        shuffleProcess.originX = normX;
        shuffleProcess.originY = normY;
        DesktopMenuController.menuOriginX = normX;
        DesktopMenuController.menuOriginY = normY;
        DesktopMenuController.isMenuShuffle = true;

        let cmd =
            "STATE_FILE='" + stateFile + "'; " +
            "CUSTOM_DIR='" + customDir + "'; " +
            "DIR=''; " +
            "if [ -n \"$CUSTOM_DIR\" ] && [ -d \"$CUSTOM_DIR\" ]; then " +
            "    DIR=\"$CUSTOM_DIR\"; " +
            "elif [ -f \"$STATE_FILE\" ]; then " +
            "    CUR=$(cat \"$STATE_FILE\" 2>/dev/null); " +
            "    if [ -n \"$CUR\" ]; then " +
            "        CANDIDATE=$(dirname \"$CUR\"); " +
            "        if [ -d \"$CANDIDATE\" ]; then DIR=\"$CANDIDATE\"; fi; " +
            "    fi; " +
            "fi; " +
            "if [ -z \"$DIR\" ] || [ ! -d \"$DIR\" ]; then " +
            "    for d in \"$HOME/Pictures/Wallpapers\" \"$HOME/Pictures/wallpapers\" \"$HOME/Wallpapers\" \"$HOME/Pictures\" \"$HOME/.config/serpantinum/wallpapers\" \"/usr/share/backgrounds\"; do " +
            "        if [ -d \"$d\" ]; then DIR=\"$d\"; break; fi; " +
            "    done; " +
            "fi; " +
            "if [ -n \"$DIR\" ] && [ -d \"$DIR\" ]; then " +
            "    find -L \"$DIR\" -maxdepth 2 -type f \\( -iname \"*.jpg\" -o -iname \"*.jpeg\" -o -iname \"*.png\" -o -iname \"*.webp\" -o -iname \"*.bmp\" -o -iname \"*.avif\" \\) 2>/dev/null | shuf -n 1; " +
            "fi";

        shuffleProcess.targetScreenName = scrName;
        shuffleProcess.command = ["bash", "-c", cmd];
        shuffleProcess.running = false;
        shuffleProcess.running = true;
    }

    function lockScreen() {
        DesktopMenuController.hide();
        let dir = (typeof Caching !== "undefined" && Caching.serpantinumDir) ? Caching.serpantinumDir : "";
        let scriptPath = dir ? (dir + "/scripts/lock.sh") : "lock.sh";
        Quickshell.execDetached(["bash", scriptPath]);
    }

    function reloadShell() {
        let dir = (typeof Caching !== "undefined" && Caching.serpantinumDir) ? Caching.serpantinumDir : "";
        let cmd = (dir ? "if [ -f '" + dir + "/scripts/reload.sh' ]; then bash '" + dir + "/scripts/reload.sh'; else " : "")
            + "if command -v serpantinum >/dev/null 2>&1; then serpantinum reload; elif command -v qs_manager.sh >/dev/null 2>&1; then qs_manager.sh reload; else pkill -USR1 quickshell || pkill -HUP quickshell; fi"
            + (dir ? "; fi" : "");
        Quickshell.execDetached(["bash", "-c", cmd]);
    }

    function openRedactor(selectedWidgetId) {
        DesktopMenuController.hide();
        let targetId = selectedWidgetId !== undefined ? String(selectedWidgetId) : "";
        let mon = (desktopMenuWindow.screen && desktopMenuWindow.screen.name) ? desktopMenuWindow.screen.name : ((DesktopMenuController.screen && DesktopMenuController.screen.name) ? DesktopMenuController.screen.name : "");
        let dir = (typeof Caching !== "undefined" && Caching.serpantinumDir) ? Caching.serpantinumDir : "";
        let scriptPath = dir ? (dir + "/scripts/redactor.sh") : "redactor.sh";
        Quickshell.execDetached(["bash", scriptPath, mon, targetId]);
    }

    function openGuide(tab) {
        DesktopMenuController.hide();
        let targetTab = tab !== undefined ? String(tab).trim() : "";
        let dir = (typeof Caching !== "undefined" && Caching.serpantinumDir) ? Caching.serpantinumDir : "";
        let args = "open settings" + (targetTab ? (" " + targetTab) : "");
        let cmd = (dir ? ("if [ -f '" + dir + "/scripts/qs_manager.sh' ]; then bash '" + dir + "/scripts/qs_manager.sh' " + args + "; else ") : "")
            + "if command -v serpantinum >/dev/null 2>&1; then serpantinum msg " + args + "; elif command -v qs_manager.sh >/dev/null 2>&1; then qs_manager.sh " + args + "; fi"
            + (dir ? "; fi" : "");
        Quickshell.execDetached(["bash", "-c", cmd]);
    }

    Item {
        id: rootContainer
        anchors.fill: parent
        focus: desktopMenuWindow.isVisible
        Keys.onEscapePressed: DesktopMenuController.hide()

        onActiveFocusChanged: {
            if (!activeFocus && desktopMenuWindow.isVisible && menuContainer.animProgress > 0.5) {
                DesktopMenuController.hide();
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: desktopMenuWindow.isVisible
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onPressed: DesktopMenuController.hide()
        }

        Item {
            id: wallpaperRing
            visible: !desktopMenuWindow.isWidgetMode && desktopMenuWindow.ringWallpapers.length > 0
            anchors.fill: parent
            opacity: Math.max(0, Math.min(1, menuContainer.animProgress))
            property int hoveredIndex: -1
            onVisibleChanged: if (!visible) hoveredIndex = -1

            // Geometry anchors for the network-style ribbons, behind the cards and menu.
            Repeater {
                id: webAnchors
                model: desktopMenuWindow.ringWallpapers
                delegate: Item {
                    id: wallpaperLink
                    objectName: "wallpaperConnector"
                    required property var modelData
                    required property int index
                    anchors.fill: parent
                    z: 0
                    readonly property real theta: -Math.PI / 2 + index * 2 * Math.PI / Math.max(1, desktopMenuWindow.ringWallpapers.length)
                    readonly property real cardWidth: desktopMenuWindow.s(114)
                    readonly property real cardHeight: desktopMenuWindow.s(76)
                    readonly property real dx: Math.cos(theta) * (desktopMenuWindow.menuWidth / 2 + desktopMenuWindow.ringSide - cardWidth / 2)
                    readonly property real dy: Math.sin(theta) * (desktopMenuWindow.menuHeight / 2 + desktopMenuWindow.ringTop - cardHeight / 2)
                    readonly property real cx: desktopMenuWindow.clampedX + desktopMenuWindow.menuWidth / 2
                    readonly property real cy: desktopMenuWindow.clampedY + desktopMenuWindow.menuHeight / 2
                    function roundedFraction(w, h, r) {
                        let low = 0;
                        let high = Math.min(w / 2 / Math.max(0.001, Math.abs(dx)), h / 2 / Math.max(0.001, Math.abs(dy)));
                        for (let n = 0; n < 14; n++) {
                            let mid = (low + high) / 2;
                            let qx = Math.max(0, Math.abs(dx * mid) - (w / 2 - r));
                            let qy = Math.max(0, Math.abs(dy * mid) - (h / 2 - r));
                            if (qx*qx + qy*qy <= r*r) low = mid;
                            else high = mid;
                        }
                        return low;
                    }
                    readonly property real menuFraction: roundedFraction(desktopMenuWindow.menuWidth, desktopMenuWindow.menuHeight, desktopMenuWindow.s(16))
                    readonly property real cardFraction: roundedFraction(cardWidth, cardHeight, desktopMenuWindow.s(13))
                    property real highlight: wallpaperRing.hoveredIndex === index ? 1 : 0
                    Behavior on highlight { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    readonly property real openScale: Math.max(0, menuContainer.animProgress)
                    readonly property real startX: desktopMenuWindow.targetX + (cx + dx * menuFraction - desktopMenuWindow.targetX) * openScale
                    readonly property real startY: desktopMenuWindow.targetY + (cy + dy * menuFraction - desktopMenuWindow.targetY) * openScale
                    readonly property real endX: cx + dx * (1 - cardFraction * (1 + highlight * 0.07))
                    readonly property real endY: cy + dy * (1 - cardFraction * (1 + highlight * 0.07))
                    readonly property real length: Math.max(1, Math.hypot(endX-startX, endY-startY))
                    readonly property real bend: desktopMenuWindow.s(8) * (index % 2 === 0 ? 1 : -1)
                    readonly property real bendX: -(endY-startY) / length * bend
                    readonly property real bendY: (endX-startX) / length * bend
                    readonly property real control1X: startX + (endX-startX) * 0.35 + bendX
                    readonly property real control1Y: startY + (endY-startY) * 0.35 + bendY
                    readonly property real control2X: startX + (endX-startX) * 0.72 + bendX
                    readonly property real control2Y: startY + (endY-startY) * 0.72 + bendY
                    readonly property color accent: modelData.color || ThemeBackend.text


                }
            }

            // Reuse the Wi-Fi/Bluetooth popup's exact flowing three-strand shader.
            // Beams run center-to-center; the menu and thumbnail surfaces cover their ends.
            ShaderEffect {
                id: wallpaperRibbons
                objectName: "networkStyleWallpaperRibbons"
                x: desktopMenuWindow.clampedX - desktopMenuWindow.ringSide - desktopMenuWindow.s(10)
                y: desktopMenuWindow.clampedY - desktopMenuWindow.ringTop - desktopMenuWindow.s(10)
                width: desktopMenuWindow.menuWidth + desktopMenuWindow.ringSide * 2 + desktopMenuWindow.s(20)
                height: desktopMenuWindow.menuHeight + desktopMenuWindow.ringTop * 2 + desktopMenuWindow.s(20)
                z: 0
                readonly property bool animating: wallpaperRing.visible && desktopMenuWindow.isVisible
                property real animTime: 0
                NumberAnimation on animTime {
                    running: wallpaperRibbons.animating
                    loops: Animation.Infinite
                    from: 0; to: 1000; duration: 1000000
                }
                property vector2d itemSize: Qt.vector2d(width, height)
                property real time: animTime
                property real strikeProg: Math.max(0, Math.min(1, menuContainer.animProgress))
                property real scale: desktopMenuWindow.s(1)
                property real coreRadius: 0
                property color activeColor: ThemeBackend.text
                function calcBeams() {
                    let beams=[];
                    for(let i=0;i<Math.min(16,webAnchors.count);i++) {
                        let link=webAnchors.itemAt(i);
                        if(!link)continue;
                        beams.push(Qt.vector4d(link.cx-x, link.cy-y,
                            link.cx+link.dx-x, link.cy+link.dy-y));
                    }
                    return beams;
                }
                property var activeBeams: {
                    // The clock also refreshes geometry after asynchronous thumbnail creation.
                    let tick=animTime;
                    let count=webAnchors.count;
                    let visible=desktopMenuWindow.isVisible;
                    return calcBeams();
                }
                property real beamCount: Math.min(16,activeBeams.length)
                property vector4d beam0: activeBeams.length > 0 ? activeBeams[0] : Qt.vector4d(-1,-1,-1,-1)
                property vector4d beam1: activeBeams.length > 1 ? activeBeams[1] : Qt.vector4d(-1,-1,-1,-1)
                property vector4d beam2: activeBeams.length > 2 ? activeBeams[2] : Qt.vector4d(-1,-1,-1,-1)
                property vector4d beam3: activeBeams.length > 3 ? activeBeams[3] : Qt.vector4d(-1,-1,-1,-1)
                property vector4d beam4: activeBeams.length > 4 ? activeBeams[4] : Qt.vector4d(-1,-1,-1,-1)
                property vector4d beam5: activeBeams.length > 5 ? activeBeams[5] : Qt.vector4d(-1,-1,-1,-1)
                property vector4d beam6: activeBeams.length > 6 ? activeBeams[6] : Qt.vector4d(-1,-1,-1,-1)
                property vector4d beam7: activeBeams.length > 7 ? activeBeams[7] : Qt.vector4d(-1,-1,-1,-1)
                property vector4d beam8: activeBeams.length > 8 ? activeBeams[8] : Qt.vector4d(-1,-1,-1,-1)
                property vector4d beam9: activeBeams.length > 9 ? activeBeams[9] : Qt.vector4d(-1,-1,-1,-1)
                property vector4d beam10: activeBeams.length > 10 ? activeBeams[10] : Qt.vector4d(-1,-1,-1,-1)
                property vector4d beam11: activeBeams.length > 11 ? activeBeams[11] : Qt.vector4d(-1,-1,-1,-1)
                property vector4d beam12: activeBeams.length > 12 ? activeBeams[12] : Qt.vector4d(-1,-1,-1,-1)
                property vector4d beam13: activeBeams.length > 13 ? activeBeams[13] : Qt.vector4d(-1,-1,-1,-1)
                property vector4d beam14: activeBeams.length > 14 ? activeBeams[14] : Qt.vector4d(-1,-1,-1,-1)
                property vector4d beam15: activeBeams.length > 15 ? activeBeams[15] : Qt.vector4d(-1,-1,-1,-1)
                fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/vfx/node_beams_clipped.frag.qsb"
            }

            Repeater {
                model: desktopMenuWindow.ringWallpapers
                delegate: Rectangle {
                    id: preview
                    required property var modelData
                    required property int index
                    property real angle: -Math.PI / 2 + index * 2 * Math.PI / Math.max(1, desktopMenuWindow.ringWallpapers.length)
                    property real radiusX: desktopMenuWindow.menuWidth / 2 + desktopMenuWindow.ringSide - width / 2
                    property real radiusY: desktopMenuWindow.menuHeight / 2 + desktopMenuWindow.ringTop - height / 2
                    width: desktopMenuWindow.s(114)
                    height: desktopMenuWindow.s(76)
                    x: desktopMenuWindow.clampedX + desktopMenuWindow.menuWidth / 2 + Math.cos(angle) * radiusX - width / 2
                    y: desktopMenuWindow.clampedY + desktopMenuWindow.menuHeight / 2 + Math.sin(angle) * radiusY - height / 2
                    radius: desktopMenuWindow.s(13)
                    color: Qt.alpha(ThemeBackend.base, 0.92)
                    border.width: 1
                    border.color: previewMouse.containsMouse ? modelData.color : Qt.alpha(ThemeBackend.text, 0.28)
                    clip: true
                    scale: previewMouse.pressed ? 0.96 : (previewMouse.containsMouse ? 1.07 : 1.0)
                    z: previewMouse.containsMouse ? 2 : 1
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    HoverHandler {
                        onHoveredChanged: {
                            if (hovered) wallpaperRing.hoveredIndex = preview.index;
                            else if (wallpaperRing.hoveredIndex === preview.index) wallpaperRing.hoveredIndex = -1;
                        }
                    }
                    Rectangle {
                        id: previewMask
                        anchors.fill: parent
                        radius: preview.radius
                        visible: false
                        layer.enabled: true
                    }
                    Image {
                        id: previewImage
                        anchors.fill: parent
                        source: preview.modelData.thumb
                        sourceSize: Qt.size(230, 150)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: false
                        onStatusChanged: if (status === Image.Error && source.toString() !== preview.modelData.url) source = preview.modelData.url
                    }
                    MultiEffect {
                        anchors.fill: parent
                        source: previewImage
                        maskEnabled: true
                        maskSource: previewMask
                    }
                    MouseArea {
                        id: previewMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: desktopMenuWindow.selectRingWallpaper(preview.modelData)
                    }
                    Rectangle {
                        anchors.top: parent.top; anchors.right: parent.right
                        anchors.margins: desktopMenuWindow.s(5)
                        width: desktopMenuWindow.s(24); height: width; radius: width / 2
                        color: Qt.rgba(0, 0, 0, 0.7)
                        visible: previewMouse.containsMouse || starMouse.containsMouse || desktopMenuWindow.favoriteWallpapers.indexOf(preview.modelData.path) >= 0
                        Text {
                            anchors.centerIn: parent
                            text: desktopMenuWindow.favoriteWallpapers.indexOf(preview.modelData.path) >= 0 ? "★" : "☆"
                            color: "white"; font.pixelSize: desktopMenuWindow.s(16)
                        }
                        MouseArea {
                            id: starMouse; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: desktopMenuWindow.toggleWallpaperFavorite(preview.modelData.path)
                        }
                    }
                }
            }
        }

        Item {
            id: menuContainer

            property real animProgress: 0.0

            NumberAnimation {
                id: openAnim
                target: menuContainer
                property: "animProgress"
                from: menuContainer.animProgress > 0.8 ? 0.2 : 0.0
                to: 1.0
                duration: 150
                easing.type: Easing.OutBack
                easing.overshoot: 1.05
            }

            NumberAnimation {
                id: closeAnim
                target: menuContainer
                property: "animProgress"
                to: 0.0
                duration: 75
                easing.type: Easing.InCubic
                onFinished: {
                    if (!desktopMenuWindow.isVisible) {
                        menuContainer.animProgress = 0.0;
                    }
                }
            }

            x: desktopMenuWindow.clampedX
            y: desktopMenuWindow.clampedY
            width: desktopMenuWindow.menuWidth
            height: desktopMenuWindow.menuHeight

            opacity: Math.max(0.0, Math.min(1.0, animProgress * 2.5))

            transform: Scale {
                origin.x: desktopMenuWindow.targetX - desktopMenuWindow.clampedX
                origin.y: desktopMenuWindow.targetY - desktopMenuWindow.clampedY
                xScale: Math.max(0.0, menuContainer.animProgress)
                yScale: Math.max(0.0, menuContainer.animProgress)
            }

            Rectangle {
                anchors.fill: parent
                radius: desktopMenuWindow.s(16)
                color: Qt.alpha(desktopMenuWindow.menuBackgroundColor, 0.76)
                border.width: 1
                border.color: Qt.alpha(ThemeBackend.text, 0.16)
                clip: true
                WallpaperBlur {
                    z: -1
                    anchors.fill: parent
                    radius: parent.radius
                }
            }

            Column {
                id: contentCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: desktopMenuWindow.s(6)
                spacing: desktopMenuWindow.s(2)

                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 0

                    Rectangle {
                        id: iconButtonsBox
                        Layout.fillWidth: true
                        Layout.preferredHeight: iconRow.implicitHeight + desktopMenuWindow.s(8)
                        color: "transparent"
                        radius: desktopMenuWindow.cornerRadius
                        clip: true

                        Row {
                            id: iconRow
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: desktopMenuWindow.s(4)
                            anchors.rightMargin: desktopMenuWindow.s(4)
                            spacing: Math.max(0, (width - desktopMenuWindow.s(36) * (desktopMenuWindow.isWidgetMode ? 2 : 4)) / (desktopMenuWindow.isWidgetMode ? 1 : 3))

                            IconButton {
                                visible: desktopMenuWindow.isWidgetMode
                                width: desktopMenuWindow.s(36)
                                height: desktopMenuWindow.s(36)
                                size: height
                                cornerRadius: desktopMenuWindow.s(8)
                                accentColor: ThemeBackend.text
                                bgOpacity: isHoveredOrHighlighted ? 0.20 : 0.0
                                textColor: ThemeBackend.text
                                buttonIcon: "󰏫"
                                iconFontSize: desktopMenuWindow.s(16)
                                onClicked: {
                                    desktopMenuWindow.openRedactor(DesktopMenuController.targetWidgetId);
                                }
                            }

                            IconButton {
                                visible: !desktopMenuWindow.isWidgetMode
                                width: desktopMenuWindow.s(36)
                                height: desktopMenuWindow.s(36)
                                size: height
                                cornerRadius: desktopMenuWindow.s(8)
                                accentColor: ThemeBackend.text
                                bgOpacity: isHoveredOrHighlighted ? 0.20 : 0.0
                                textColor: ThemeBackend.text
                                buttonIcon: "󰒝"
                                iconFontSize: desktopMenuWindow.s(16)
                                onClicked: {
                                    desktopMenuWindow.shuffleWallpaper();
                                    DesktopMenuController.hide();
                                }
                            }

                            IconButton {
                                visible: !desktopMenuWindow.isWidgetMode
                                width: desktopMenuWindow.s(36); height: desktopMenuWindow.s(36); size: height
                                cornerRadius: desktopMenuWindow.s(8)
                                accentColor: ThemeBackend.text
                                bgOpacity: isHoveredOrHighlighted ? 0.20 : 0.0
                                textColor: ThemeBackend.text
                                buttonIcon: "󰑓"; iconFontSize: desktopMenuWindow.s(16)
                                ToolTip.visible: isHoveredOrHighlighted
                                ToolTip.delay: 600
                                ToolTip.text: "Refresh wallpaper previews"
                                onClicked: desktopMenuWindow.refreshWallpaperRing()
                            }

                            IconButton {
                                id: nightLightBtn
                                visible: !desktopMenuWindow.isWidgetMode
                                width: desktopMenuWindow.s(36)
                                height: desktopMenuWindow.s(36)
                                size: height
                                cornerRadius: desktopMenuWindow.s(8)
                                accentColor: desktopMenuWindow.isNightLightActive ? ((typeof ThemeBackend !== "undefined" && ThemeBackend.peach) ? ThemeBackend.peach : "#fab387") : desktopMenuWindow.buttonColor
                                bgOpacity: desktopMenuWindow.isNightLightActive ? 0.8 : (isHoveredOrHighlighted ? 0.20 : 0.0)
                                textColor: desktopMenuWindow.isNightLightActive ? ((typeof ThemeBackend !== "undefined" && ThemeBackend.crust) ? ThemeBackend.crust : ((typeof ThemeBackend !== "undefined" && ThemeBackend.base) ? ThemeBackend.base : "#1e1e2e")) : ((typeof ThemeBackend !== "undefined" && ThemeBackend.text) ? ThemeBackend.text : "#cdd6f4")
                                buttonIcon: "󰖔"
                                iconFontSize: desktopMenuWindow.s(16)
                                onClicked: {
                                    desktopMenuWindow.toggleNightLight();
                                }
                            }

                            IconButton {
                                id: lockBtn
                                visible: !desktopMenuWindow.isWidgetMode
                                width: desktopMenuWindow.s(36)
                                height: desktopMenuWindow.s(36)
                                size: height
                                cornerRadius: desktopMenuWindow.s(8)
                                accentColor: ThemeBackend.text
                                bgOpacity: isHoveredOrHighlighted ? 0.20 : 0.0
                                textColor: ThemeBackend.text
                                buttonIcon: ""
                                iconFontSize: desktopMenuWindow.s(16)
                                onClicked: {
                                    desktopMenuWindow.lockScreen();
                                }
                            }

                            DeleteButton {
                                visible: desktopMenuWindow.isWidgetMode
                                width: desktopMenuWindow.s(36)
                                height: desktopMenuWindow.s(36)
                                size: height
                                cornerRadius: desktopMenuWindow.s(8)
                                accentColor: (typeof ThemeBackend !== "undefined" && ThemeBackend.red) ? Qt.rgba(ThemeBackend.red.r, ThemeBackend.red.g, ThemeBackend.red.b, 0.22) : "#452026"
                                bgOpacity: isHoveredOrHighlighted ? 0.20 : 0.0
                                textColor: (typeof ThemeBackend !== "undefined" && ThemeBackend.red) ? ThemeBackend.red : "#f38ba8"
                                onClicked: {
                                    let wId = DesktopMenuController.targetWidgetId;
                                    if (wId) {
                                        let mon = (desktopMenuWindow.screen && desktopMenuWindow.screen.name) ? desktopMenuWindow.screen.name : ((DesktopMenuController.screen && DesktopMenuController.screen.name) ? DesktopMenuController.screen.name : "");
                                        let safeMon = mon.replace(/[^a-zA-Z0-9_-]/g, "_");
                                        if (typeof WidgetSync !== "undefined") {
                                            WidgetSync.removeWidget(mon, wId);
                                        }
                                        let mainQml = (typeof Caching !== "undefined" && Caching.mainQml) ? Caching.mainQml : "";
                                        if (mainQml) {
                                            Quickshell.execDetached(["quickshell", "-p", mainQml, "ipc", "call", "widgets-" + safeMon, "remove", wId]);
                                        }
                                    }
                                    DesktopMenuController.hide();
                                }
                            }
                        }
                    }

                }

                Rectangle {
                    id: clickButtonsBox
                    width: parent.width
                    height: clickButtonsCol.implicitHeight + desktopMenuWindow.s(8)
                    color: "transparent"
                    radius: desktopMenuWindow.cornerRadius
                    clip: true

                    Column {
                        id: clickButtonsCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: desktopMenuWindow.s(4)
                        spacing: desktopMenuWindow.s(2)

                        ClickButton {
                            visible: desktopMenuWindow.isWidgetMode
                            width: parent.width
                            height: desktopMenuWindow.s(29)
                            cornerRadius: desktopMenuWindow.s(8)
                            contentAlignment: Qt.AlignLeft
                            horizontalPadding: desktopMenuWindow.s(10)
                            buttonIcon: "󰕰"
                            iconFontSize: desktopMenuWindow.s(15)
                            textFontSize: desktopMenuWindow.s(12)
                            buttonText: {
                                if (typeof I18n !== "undefined" && typeof I18n.t === "function") {
                                    let val = I18n.t("guide.display.widgets.open", "Open Redactor");
                                    if (val && val !== "guide.display.widgets.open") return val;
                                    return "Open Redactor";
                                }
                                return "Open Redactor";
                            }
                            accentColor: ThemeBackend.text
                            bgOpacity: isHoveredOrHighlighted ? 0.20 : 0.0
                            textColor: ThemeBackend.text
                            onClicked: {
                                desktopMenuWindow.openRedactor("");
                            }
                        }

                        ClickButton {
                            visible: !desktopMenuWindow.isWidgetMode
                            width: parent.width
                            height: desktopMenuWindow.s(29)
                            cornerRadius: desktopMenuWindow.s(8)
                            contentAlignment: Qt.AlignLeft
                            horizontalPadding: desktopMenuWindow.s(10)
                            buttonIcon: "󰸉"
                            iconFontSize: desktopMenuWindow.s(15)
                            textFontSize: desktopMenuWindow.s(12)
                            buttonText: {
                                if (typeof I18n !== "undefined" && typeof I18n.t === "function") {
                                    let val = I18n.t("guide.theme.wallpaper.select_wallpaper", "Select Wallpaper");
                                    if (val && val !== "guide.theme.wallpaper.select_wallpaper") return val;
                                    return "Select Wallpaper";
                                }
                                return "Select Wallpaper";
                            }
                            accentColor: ThemeBackend.text
                            bgOpacity: isHoveredOrHighlighted ? 0.20 : 0.0
                            textColor: ThemeBackend.text
                            onClicked: {
                                DesktopMenuController.hide();
                                let dir = (typeof Caching !== "undefined" && Caching.serpantinumDir) ? Caching.serpantinumDir : "";
                                if (dir) {
                                    Quickshell.execDetached(["bash", "-c", dir + "/scripts/qs_manager.sh toggle wallpaper"]);
                                } else {
                                    Quickshell.execDetached(["bash", "-c", "qs_manager.sh toggle wallpaper"]);
                                }
                            }
                        }

                        ClickButton {
                            visible: !desktopMenuWindow.isWidgetMode
                            width: parent.width
                            height: desktopMenuWindow.s(29)
                            cornerRadius: desktopMenuWindow.s(8)
                            contentAlignment: Qt.AlignLeft
                            horizontalPadding: desktopMenuWindow.s(10)
                            buttonIcon: "󰕰"
                            iconFontSize: desktopMenuWindow.s(15)
                            textFontSize: desktopMenuWindow.s(12)
                            buttonText: {
                                if (typeof I18n !== "undefined" && typeof I18n.t === "function") {
                                    let val = I18n.t("guide.display.widgets.open", "Widget Redactor");
                                    if (val && val !== "guide.display.widgets.open") return val;
                                    return "Widget Redactor";
                                }
                                return "Widget Redactor";
                            }
                            accentColor: ThemeBackend.text
                            bgOpacity: isHoveredOrHighlighted ? 0.20 : 0.0
                            textColor: ThemeBackend.text
                            onClicked: {
                                desktopMenuWindow.openRedactor("");
                            }
                        }

                        ClickButton {
                            visible: !desktopMenuWindow.isWidgetMode
                            width: parent.width
                            height: desktopMenuWindow.s(29)
                            cornerRadius: desktopMenuWindow.s(8)
                            contentAlignment: Qt.AlignLeft
                            horizontalPadding: desktopMenuWindow.s(10)
                            buttonIcon: "󰏘"
                            iconFontSize: desktopMenuWindow.s(15)
                            textFontSize: desktopMenuWindow.s(12)
                            buttonText: {
                                if (typeof I18n !== "undefined" && typeof I18n.t === "function") {
                                    let val = I18n.t("guide.tabs.theme", "Theme");
                                    if (val && val !== "guide.tabs.theme") return val;
                                    return "Theme";
                                }
                                return "Theme";
                            }
                            accentColor: ThemeBackend.text
                            bgOpacity: isHoveredOrHighlighted ? 0.20 : 0.0
                            textColor: ThemeBackend.text
                            onClicked: {
                                desktopMenuWindow.openGuide("theme");
                            }
                        }
                    }
                }

                Rectangle {
                    id: settingsBox
                    width: parent.width
                    height: settingsCol.implicitHeight + desktopMenuWindow.s(8)
                    color: "transparent"
                    radius: desktopMenuWindow.cornerRadius
                    clip: true

                    Column {
                        id: settingsCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: desktopMenuWindow.s(4)

                        ClickButton {
                            width: parent.width
                            height: desktopMenuWindow.s(29)
                            cornerRadius: desktopMenuWindow.s(8)
                            contentAlignment: Qt.AlignLeft
                            horizontalPadding: desktopMenuWindow.s(10)
                            buttonIcon: "󰒓"
                            iconFontSize: desktopMenuWindow.s(15)
                            textFontSize: desktopMenuWindow.s(12)
                            buttonText: {
                                if (typeof I18n !== "undefined" && typeof I18n.t === "function") {
                                    let val = I18n.t("widgets.guide.name", "Settings");
                                    if (val && val !== "widgets.guide.name") return val;
                                    return "Settings";
                                }
                                return "Settings";
                            }
                            accentColor: ThemeBackend.text
                            bgOpacity: isHoveredOrHighlighted ? 0.20 : 0.0
                            textColor: ThemeBackend.text
                            onClicked: {
                                if (desktopMenuWindow.isWidgetMode) {
                                    desktopMenuWindow.openGuide("display_widgets");
                                } else {
                                    desktopMenuWindow.openGuide("");
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
