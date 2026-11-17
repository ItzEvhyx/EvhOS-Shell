import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../"
import "OverviewLogic.js" as Logic

Rectangle {
    id: card
    required property int workspaceId
    property var workspaceObject: null
    property var fallbackMonitor: null
    // local active wallpaper previews v1
    property Item wallpaperSource: null
    property bool selected: false
    property bool captureLive: false
    property real uiScale: 1
    signal activated()

    function s(value) { return value * uiScale; }
    readonly property var monitor: workspaceObject && workspaceObject.monitor ? workspaceObject.monitor : fallbackMonitor
    readonly property var clients: workspaceObject && workspaceObject.toplevels ? workspaceObject.toplevels.values.filter(client => (client.lastIpcObject || {}).mapped !== false) : []
    readonly property var visibleClients: clients.filter(client => (client.lastIpcObject || {}).hidden !== true)
    readonly property var appIds: {
        let result = [];
        for (let client of clients) {
            let data = client.lastIpcObject || {};
            let app = AppMatcher.resolve(data.class || data.initialClass || (client.wayland ? client.wayland.appId : ""));
            if (app && result.indexOf(app) < 0) result.push(app);
        }
        return result;
    }
    readonly property string wallpaper: {
        let path = Wallpaper.getWallpaperPath(monitor ? monitor.name : "");
        if (!path || /\.(mp4|webm|mkv|mov)(?:[?#].*)?$/i.test(path)) return "";
        return path.startsWith("file:") ? path : "file://" + path;
    }

    function iconFor(app) {
        let entry = AppMatcher.entry(app);
        return Quickshell.iconPath(entry && entry.icon ? entry.icon : app, true)
               || Quickshell.iconPath("application-x-executable", true);
    }

    radius: s(22)
    color: Qt.alpha(ThemeBackend.base, selected ? 0.72 : 0.52)
    border.width: selected ? s(2) : 1
    border.color: Qt.alpha(ThemeBackend.text, selected ? 0.95 : (pointer.containsMouse ? 0.46 : 0.18))
    scale: pointer.pressed ? 0.985 : 1
    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    Behavior on border.color { ColorAnimation { duration: 160 } }
    Accessible.role: Accessible.Button
    Accessible.name: clients.length ? "Workspace " + workspaceId + ", " + appIds.join(", ") : "Empty workspace " + workspaceId
    Accessible.onPressAction: activated()

    Item {
        id: preview
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: card.s(5) }
        height: Math.max(1, card.height - card.s(44))
        Rectangle { id: previewMask; anchors.fill: parent; radius: card.s(18); color: "white"; visible: false; layer.enabled: true }
        Item {
            anchors.fill: parent
            clip: true
            layer.enabled: true
            layer.effect: MultiEffect { maskEnabled: true; maskSource: previewMask }
            Rectangle { anchors.fill: parent; color: ThemeBackend.surface0 }
            Image {
                anchors.fill: parent
                source: card.wallpaper
                visible: !card.wallpaperSource
                sourceSize: Qt.size(960, 540)
                asynchronous: true
                cache: false
                retainWhileLoading: false
                fillMode: Image.PreserveAspectCrop
            }
            ShaderEffectSource {
                id: wallpaperTexture
                objectName: "workspace-wallpaper-texture"
                anchors.fill: parent
                sourceItem: card.wallpaperSource
                visible: sourceItem !== null
                live: card.captureLive
                smooth: true
                textureSize: Qt.size(Math.max(1, Math.ceil(width)), Math.max(1, Math.ceil(height)))
                sourceRect: {
                    if (!sourceItem || sourceItem.width <= 0 || sourceItem.height <= 0) return Qt.rect(0, 0, 1, 1);
                    let scale = Math.max(width / sourceItem.width, height / sourceItem.height);
                    let w = width / Math.max(scale, 0.001), h = height / Math.max(scale, 0.001);
                    return Qt.rect((sourceItem.width - w) / 2, (sourceItem.height - h) / 2, w, h);
                }
            }
            Rectangle { anchors.fill: parent; color: card.clients.length ? "#10000000" : "#50000000" }

            Repeater {
                model: ScriptModel { values: card.visibleClients }
                delegate: Item {
                    id: miniature
                    required property var modelData
                    readonly property var geometry: Logic.windowRect(modelData, card.monitor, preview.width, preview.height)
                    readonly property string appId: AppMatcher.resolve(modelData.lastIpcObject.class || modelData.lastIpcObject.initialClass || "")
                    x: geometry.x; y: geometry.y; width: geometry.width; height: geometry.height
                    z: (modelData.lastIpcObject.floating ? 50 : 0) + (modelData.activated ? 20 : 1)
                    Rectangle { anchors.fill: parent; color: ThemeBackend.surface1; radius: card.s(3) }
                    Image {
                        anchors.centerIn: parent
                        width: Math.min(card.s(44), parent.width * 0.35)
                        height: width
                        source: card.iconFor(miniature.appId)
                        visible: !capture.hasContent
                    }
                    ScreencopyView {
                        id: capture
                        anchors.fill: parent
                        captureSource: card.captureLive && miniature.modelData ? miniature.modelData.wayland : null
                        live: card.captureLive
                        paintCursor: false
                        constraintSize: Qt.size(miniature.width, miniature.height)
                        visible: hasContent
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: card.clients.length === 0
                text: "+"
                color: Qt.alpha(ThemeBackend.text, 0.88)
                font.family: ThemeBackend.fontFamily
                font.pixelSize: card.s(44)
                font.weight: Font.Light
            }
        }
    }

    Row {
        id: icons
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: card.s(9)
        spacing: Math.min(card.s(8), card.width / Math.max(5, card.appIds.length * 5))
        Repeater {
            model: ScriptModel { values: card.appIds }
            delegate: Image {
                required property string modelData
                width: Math.min(card.s(24), (card.width - card.s(24) - Math.max(0,card.appIds.length-1)*icons.spacing) / Math.max(1,card.appIds.length)); height: width
                source: card.iconFor(modelData)
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                ToolTip.visible: iconHover.hovered
                ToolTip.text: { let entry = AppMatcher.entry(modelData); return entry ? entry.name : modelData; }
                HoverHandler { id: iconHover }
            }
        }
    }
    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.activated()
    }
}
