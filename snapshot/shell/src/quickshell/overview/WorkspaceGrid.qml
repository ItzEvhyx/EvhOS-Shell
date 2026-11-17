import QtQuick
import QtQuick.Controls
import Quickshell
import "../"
import "OverviewLogic.js" as Logic

FocusScope {
    id: root
    property bool active: false
    property real entryProgress: 1
    property real verticalOffset: (1 - entryProgress) * 22
    property bool capturePreviews: active
    property var workspaceIds: []
    property int currentWorkspace: 1
    property var workspaceLookup: function(id) { return null; }
    property var fallbackMonitor: null
    property string errorText: ""
    property bool switching: false
    property real uiScale: 1
    property int selectedIndex: 0
    property int selectedWorkspaceId: 1
    // local active wallpaper previews v1
    property var wallpaperSources: ({})
    function registerWallpaperSource(name, item) {
        let sources = Object.assign({}, wallpaperSources);
        sources[name] = item;
        wallpaperSources = sources;
    }
    function unregisterWallpaperSource(name, item) {
        if (wallpaperSources[name] !== item) return;
        let sources = Object.assign({}, wallpaperSources);
        delete sources[name];
        wallpaperSources = sources;
    }
    Repeater {
        model: ScriptModel { values: root.capturePreviews ? Quickshell.screens.map(screen => screen) : [] }
        delegate: WorkspaceWallpaperSource {
            id: sharedWallpaper
            required property var modelData
            monitorName: modelData ? modelData.name : ""
            playbackActive: root.capturePreviews
            width: 960 * Math.min(1, modelData.width / Math.max(1, modelData.height))
            height: 960 * Math.min(1, modelData.height / Math.max(1, modelData.width))
            visible: false
            Component.onCompleted: {
                registrationName = monitorName;
                root.registerWallpaperSource(registrationName, sharedWallpaper);
            }
            Component.onDestruction: root.unregisterWallpaperSource(registrationName, sharedWallpaper)
        }
    }
    signal accepted(int workspaceId)
    signal canceled()
    readonly property var metrics: Logic.layout(width, height, workspaceIds.length, uiScale)
    function s(value) { return value * uiScale; }
    function choose(index) {
        if (!switching && index >= 0 && index < workspaceIds.length) accepted(workspaceIds[index]);
    }
    function navigate(direction) {
        selectedIndex = Logic.moveIndex(selectedIndex, direction, metrics.columns, workspaceIds.length);
    }
    onActiveChanged: {
        if (active) {
            selectedIndex = Math.max(0, workspaceIds.indexOf(currentWorkspace));
            Qt.callLater(() => forceActiveFocus());
        }
    }
    onWorkspaceIdsChanged: {
        let previous = workspaceIds.indexOf(selectedWorkspaceId);
        selectedIndex = previous >= 0 ? previous : Math.max(0, Math.min(selectedIndex,workspaceIds.length-1));
    }
    onSelectedIndexChanged: {
        if (selectedIndex >= 0 && selectedIndex < workspaceIds.length) selectedWorkspaceId = workspaceIds[selectedIndex];
        grid.positionViewAtIndex(selectedIndex, GridView.Contain);
    }
    Keys.priority: Keys.BeforeItem
    Keys.onPressed: event => {
        event.accepted = true;
        if (event.key === Qt.Key_Escape) canceled();
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) choose(selectedIndex);
        else if (event.key === Qt.Key_Left) navigate("left");
        else if (event.key === Qt.Key_Right) navigate("right");
        else if (event.key === Qt.Key_Up) navigate("up");
        else if (event.key === Qt.Key_Down) navigate("down");
        else if (event.key === Qt.Key_Home) navigate("home");
        else if (event.key === Qt.Key_End) navigate("end");
    }

    // Hyprland blurs the live desktop behind this translucent pane.
    // The cards and controls are painted above it and remain sharp.
    Rectangle {
        objectName: "overview-live-backdrop"
        anchors.fill: parent
        color: "#57050810"
    }
    MouseArea { anchors.fill: parent; onClicked: root.canceled() }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.s(36)
        text: "Workspaces"
        font.family: ThemeBackend.fontFamily
        font.pixelSize: root.s(23)
        font.weight: Font.Medium
        color: ThemeBackend.text
    }
    Rectangle {
        anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: root.s(28)
        width: root.s(34); height: width; radius: width / 2
        color: Qt.alpha(ThemeBackend.text, closeMouse.containsMouse ? 0.13 : 0.04)
        Text { anchors.centerIn: parent; text: "×"; font.pixelSize: root.s(25); color: ThemeBackend.text }
        MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.canceled() }
    }

    GridView {
        id: grid
        objectName: "workspace-grid"
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.s(9)
        anchors.horizontalCenterOffset: root.metrics.gap / 2
        width: root.metrics.width + root.metrics.gap
        height: root.metrics.height
        opacity: Math.min(1, root.entryProgress * 1.2)
        scale: 0.97 + 0.03 * root.entryProgress
        transform: Translate { y: root.s(root.verticalOffset) }
        cellWidth: root.metrics.cardWidth + root.metrics.gap
        cellHeight: root.metrics.cardHeight + root.metrics.gap
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: ScriptModel { values: root.workspaceIds }
        delegate: WorkspaceCard {
            required property int modelData
            required property int index
            objectName: "workspace-card-" + modelData
            width: root.metrics.cardWidth
            height: root.metrics.cardHeight
            workspaceId: modelData
            workspaceObject: root.workspaceLookup(modelData)
            fallbackMonitor: root.fallbackMonitor
            wallpaperSource: root.wallpaperSources[monitor ? monitor.name : ""] || null
            selected: index === root.selectedIndex
            captureLive: root.capturePreviews
            uiScale: root.uiScale
            onActivated: { root.selectedIndex = index; root.choose(index); }
        }
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.s(28)
        text: root.errorText || (root.switching ? "Switching workspace…" : "← ↑ ↓ →  Select     Enter  Switch     Esc  Close")
        font.family: ThemeBackend.fontFamily
        font.pixelSize: root.s(12)
        color: ThemeBackend.subtext0
    }
}
