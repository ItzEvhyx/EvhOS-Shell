import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris
import "../../../reusables"
import "../../../"

Item {
    id: root

    property var module: null
    property var widget: module

    property string orientation: (activeTarget && activeTarget.orientation !== undefined) ? activeTarget.orientation : "horizontal"
    readonly property bool isVertical: orientation === "vertical"

    readonly property var activeTarget: widget || module
    readonly property bool isCompact: activeTarget ? activeTarget.isCompact : false
    readonly property var barWindow: activeTarget ? activeTarget.barWindow : null
    readonly property bool isPreview: activeTarget ? Boolean(activeTarget.isPreview) : false
    readonly property bool isRightBar: module ? module.isRightBar : (barWindow ? (barWindow.barPosition === "right") : false)
    readonly property real barOpacity: ThemeBackend.elementOpacity

    function openMediaPanel() {
        if (root.isPreview) return;
        if (root.barWindow && !root.isVertical) {
            let point = root.mapToItem(null, 0, 0);
            OsdController.mediaPanelAnchor = {
                screen: root.barWindow.screen,
                centerX: point.x + root.width / 2,
                minX: root.barWindow.currentBarMinX,
                maxX: root.barWindow.currentBarMaxX
            };
        } else {
            OsdController.mediaPanelAnchor = null;
        }
        PanelActions.invoke("toggle", "music", "");
    }

    property int configRevision: 0

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() { root.configRevision++; }
        function onRawSettingsChanged() { root.configRevision++; }
    }

    function readBool(widgetKey, configKey) {
        if (widget && widget !== root && widget[widgetKey] !== undefined) return Boolean(widget[widgetKey]);
        if (module && module[widgetKey] !== undefined) return Boolean(module[widgetKey]);
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            let bs = Config.rawSettings.bar;
            if (bs[configKey] !== undefined) return Boolean(bs[configKey]);
        }
        return true;
    }

    function readValue(widgetKey, configKey, fallback) {
        if (widget && widget !== root && widget[widgetKey] !== undefined) return widget[widgetKey];
        if (module && module[widgetKey] !== undefined) return module[widgetKey];
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            let bs = Config.rawSettings.bar;
            if (bs[configKey] !== undefined) return bs[configKey];
        }
        return fallback;
    }

    readonly property string infoMode: readValue("mediaInfoMode", "mediaInfoMode", "duration")
    readonly property real configuredWidth: Number(readValue("mediaWidth", "mediaWidth", 120))
    readonly property bool showControls: readBool("mediaShowControls", "mediaShowControls")
    readonly property bool showIcon: isVertical ? (readBool("mediaShowIcon", "mediaShowIcon") || !showControls) : false

    property var player: MprisController.activePlayer
    readonly property bool hasArt: !isPreview && isMediaActive && !!MprisController.artUrl

    property var playerList: {
        if (!Mpris.players || !Mpris.players.values) return [];
        let list = [];
        let vals = Mpris.players.values;
        for (let i = 0; i < vals.length; i++) {
            if (vals[i]) list.push(vals[i]);
        }
        return list;
    }

    property var manualPlayer: null

    property var targetPlayer: {
        if (manualPlayer) {
            for (let i = 0; i < playerList.length; i++) {
                if (playerList[i] === manualPlayer) return manualPlayer;
            }
        }
        return MprisController.activePlayer;
    }

    property bool hasTargetPlayer: targetPlayer !== null
    property bool isMediaActive: isVertical
        ? (targetPlayer !== null && targetPlayer.playbackState !== MprisPlaybackState.Stopped && targetPlayer.trackTitle !== "")
        : (isPreview || (player !== null && player.playbackState !== MprisPlaybackState.Stopped && player.trackTitle !== ""))
    readonly property bool isPlaying: isVertical
        ? (targetPlayer ? (targetPlayer.playbackState === MprisPlaybackState.Playing || targetPlayer.isPlaying) : false)
        : (isPreview || (isMediaActive && (player ? (player.playbackState === MprisPlaybackState.Playing || player.isPlaying) : MprisController.isPlaying)))

    property string rawArtUrl: {
        if (!targetPlayer) return "";
        if (targetPlayer === MprisController.activePlayer) {
            return MprisController.artUrl;
        }
        return targetPlayer.trackArtUrl || "";
    }

    property string activeArtUrl: {
        if (isPreview || !rawArtUrl) return "";
        if (rawArtUrl.startsWith("file://") || rawArtUrl.startsWith("http")) return rawArtUrl;
        return "file://" + rawArtUrl;
    }

    function sc(v) { return barWindow ? barWindow.cs(v) : v; }

    // local compact horizontal media v2
    readonly property string horizontalTitle: root.isPreview ? I18n.t("guide.bar.media.preview.title", "Song title") : (isMediaActive ? (player ? player.trackTitle : "") : I18n.t("music.nothing_playing"))
    TextMetrics {
        id: compactTitleMetrics
        text: root.horizontalTitle
        font.family: ThemeBackend.fontFamily
        font.weight: Font.Black
        font.pixelSize: root.sc(root.isCompact ? 11 : 12)
    }
    readonly property real naturalColWidth: Math.ceil(Math.min(sc(Math.min(configuredWidth, 180)), Math.max(sc(60), compactTitleMetrics.advanceWidth)))
    readonly property real soloMediaWidth: !isVertical && barWindow && barWindow.horizontalLayout ? (barWindow.horizontalLayout.notchSoloMediaWidth || 0) : 0
    property real colWidth: Math.max(naturalColWidth, soloMediaWidth - (showControls ? sc(24) * 3 + btnSpacing * 2 + innerSpacing : 0) - sidePadding * 2 - controlHoverExtra)
    property real innerSpacing: sc(4)
    property real btnSpacing: sc(2)
    property real sidePadding: sc(4)

    property real baseHeight: {
        let h = sc(isCompact ? 8 : 9);
        if (showIcon) h += sc(isCompact ? 26 : 28);
        if (showIcon && showControls) h += sc(isCompact ? 4 : 5);
        if (showControls) h += sc(isCompact ? 74 : 80) + sc(isCompact ? 6 : 8);
        return h;
    }

    property real controlHoverExtra: 0
    property real targetLength: {
        if (module && !module.moduleActive) return 0;
        if (isVertical) return baseHeight;
        let iconW = 0;
        if (showIcon) {
            let thumbW = barWindow ? barWindow.cs(isCompact ? 26 : 28) : (isCompact ? 26 : 28);
            let gapInfo = barWindow ? barWindow.cs(isCompact ? 8 : 10) : (isCompact ? 8 : 10);
            iconW = thumbW + gapInfo;
        }
        let btnW = 0;
        if (showControls) {
            btnW = sc(24) * 3 + btnSpacing * 2 + innerSpacing;
        }
        let margins = sidePadding * 2;
        return iconW + colWidth + btnW + margins + controlHoverExtra;
    }

    implicitWidth: isVertical ? (isPreview ? (barWindow ? barWindow.cs(56) : 56) : (activeTarget ? activeTarget.width : 0)) : targetLength
    implicitHeight: isVertical ? targetLength : (barWindow ? barWindow.cs(isCompact ? 40 : 44) : (isCompact ? 40 : 44))

    function formatTime(sec) {
        sec = Math.floor(sec || 0);
        let m = Math.floor(sec / 60), s = sec % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.isVertical ? verticalBody : horizontalBody
    }

    Component {
        id: horizontalBody

        Item {
            Item {
                id: mediaLayoutContainer
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: root.sidePadding
                anchors.right: parent.right
                anchors.rightMargin: root.sidePadding
                height: parent.height
                clip: true

                Row {
                    id: innerMediaLayout
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.innerSpacing

                    MouseArea {
                        id: mediaInfoMouse
                        width: infoLayout.implicitWidth
                        height: mediaLayoutContainer.height
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openMediaPanel()

                        Row {
                            id: infoLayout
                            layoutDirection: Qt.RightToLeft // local media layout
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: barWindow ? barWindow.cs(root.isCompact ? 8 : 10) : (root.isCompact ? 8 : 10)
                            transformOrigin: Item.Left

                            scale: mediaInfoMouse.pressed ? 0.92 : (mediaInfoMouse.containsMouse ? 1.06 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

                            Rectangle {
                                id: mediaThumbBox
                                visible: root.showIcon
                                width: barWindow ? barWindow.cs(root.isCompact ? 26 : 28) : (root.isCompact ? 26 : 28)
                                height: barWindow ? barWindow.cs(root.isCompact ? 26 : 28) : (root.isCompact ? 26 : 28)
                                radius: Math.min(width, height) / 2 // local circular artwork
                                color: "transparent" // local icon-only horizontal media artwork
                                clip: !mediaThumbGlass.active
                                anchors.verticalCenter: parent.verticalCenter

                                GlassFill {
                                    id: mediaThumbGlass
                                    visible: false // local icon-only media artwork
                                    anchors.fill: parent
                                    radius: parent.radius
                                    tintColor: ThemeBackend.surface1
                                    tintAmount: 0.3
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰎈"
                                    font.family: ThemeBackend.iconFont
                                    font.pixelSize: barWindow ? barWindow.cs(root.isCompact ? 13 : 14) : (root.isCompact ? 13 : 14)
                                    color: root.isCompact ? ThemeBackend.text : ThemeBackend.subtext0
                                    visible: !root.hasArt
                                }

                                BoundedImage {
                                    id: mediaArtImg
                                    anchors.fill: parent
                                    source: root.hasArt ? (MprisController.artUrl.startsWith("file://") || MprisController.artUrl.startsWith("http") ? MprisController.artUrl : "file://" + MprisController.artUrl) : ""
                                    fillMode: Image.PreserveAspectCrop
                                    visible: false
                                }

                                MultiEffect {
                                    anchors.fill: mediaArtImg
                                    source: mediaArtImg
                                    maskEnabled: true
                                    maskSource: mediaArtMask
                                    visible: root.hasArt && mediaArtImg.status === Image.Ready
                                }

                                Item {
                                    id: mediaArtMask
                                    anchors.fill: parent
                                    layer.enabled: true
                                    visible: false

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: mediaThumbBox.radius
                                        color: "black"
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: ThemeBackend.surface0
                                    opacity: 0.15
                                    visible: root.hasArt && mediaArtImg.status === Image.Ready
                                }
                            }

                            Column {
                                spacing: -2
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.colWidth

                                MarqueeText {
                                    width: parent.width
                                    text: root.horizontalTitle
                                    color: ThemeBackend.text
                                    font.family: ThemeBackend.fontFamily
                                    font.weight: Font.Black
                                    font.pixelSize: barWindow ? barWindow.cs(root.isCompact ? 11 : 12) : (root.isCompact ? 11 : 12)
                                    marqueeSpacing: barWindow ? barWindow.cs(40) : 40
                                    speed: 30
                                    active: Boolean(root.visible && (!barWindow || barWindow.visible) && (!module || module.moduleActive) && root.isPlaying)
                                }

                                Visualizer {
                                    id: mediaPreviewVisualizer
                                    width: parent.width
                                    height: barWindow ? barWindow.cs(root.isCompact ? 9 : 10) : 10
                                    visible: root.isMediaActive
                                    active: root.isPreview || (root.isMediaActive && root.isPlaying && root.visible && (!barWindow || barWindow.visible))
                                    previewDemo: root.isPreview
                                    count: 18
                                    mirrored: false
                                    alignment: "end"
                                    spacing: 2
                                    minLength: 1
                                    color: ThemeBackend.mauve
                                    rise: 0.5
                                    fall: 0.35
                                    property bool subscribed: false
                                    function updateSubscription() {
                                        let want = active && !root.isPreview;
                                        if (want && !subscribed) { Cava.registerConsumer(); subscribed = true; }
                                        else if (!want && subscribed) { Cava.unregisterConsumer(); subscribed = false; }
                                    }
                                    onActiveChanged: updateSubscription()
                                    Component.onCompleted: updateSubscription()
                                    Component.onDestruction: if (subscribed) Cava.unregisterConsumer()
                                }
                            }
                        }
                    }

                    Row {
                        id: buttonRow
                        property real extra: (prevMediaButton.isHoveredOrHighlighted ? root.sc(10) : 0) + (playMediaButton.isHoveredOrHighlighted ? root.sc(10) : 0) + (nextMediaButton.isHoveredOrHighlighted ? root.sc(10) : 0)
                        Component.onCompleted: root.controlHoverExtra = Qt.binding(() => extra)
                        visible: root.showControls
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: root.btnSpacing

                        IconButton {
                            id: prevMediaButton
                            height: barWindow ? barWindow.cs(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)
                            width: root.sc(24) + (isHoveredOrHighlighted ? root.sc(10) : 0)
                            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            scale: pressed ? 0.91 : (isHoveredOrHighlighted ? 1.2 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            cornerRadius: barWindow ? barWindow.cs(root.isCompact ? 9 : 10) : (root.isCompact ? 9 : 10)
                            buttonIcon: "󰒮"
                            iconFontSize: barWindow ? barWindow.cs(root.isCompact ? 7 : 8) : (root.isCompact ? 7 : 8)
                            accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
                            bgOpacity: 0 // local icon-only media controls
                            textColor: isHoveredOrHighlighted ? ThemeBackend.text : (root.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2)
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: if (player && player.canGoPrevious) player.previous()
                        }

                        IconButton {
                            id: playMediaButton
                            height: barWindow ? barWindow.cs(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)
                            width: root.sc(24) + (isHoveredOrHighlighted ? root.sc(10) : 0)
                            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            scale: pressed ? 0.91 : (isHoveredOrHighlighted ? 1.2 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            cornerRadius: barWindow ? barWindow.cs(root.isCompact ? 9 : 10) : (root.isCompact ? 9 : 10)
                            buttonIcon: root.isPlaying ? "󰏤" : "󰐊"
                            iconFontSize: barWindow ? barWindow.cs(root.isCompact ? 9 : 10) : (root.isCompact ? 9 : 10)
                            accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
                            bgOpacity: 0 // local icon-only media controls
                            textColor: isHoveredOrHighlighted ? ThemeBackend.green : (root.isCompact ? Qt.lighter(ThemeBackend.text, 1.1) : ThemeBackend.text)
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: if (player && player.canTogglePlaying) player.togglePlaying()
                        }

                        IconButton {
                            id: nextMediaButton
                            height: barWindow ? barWindow.cs(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)
                            width: root.sc(24) + (isHoveredOrHighlighted ? root.sc(10) : 0)
                            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            scale: pressed ? 0.91 : (isHoveredOrHighlighted ? 1.2 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            cornerRadius: barWindow ? barWindow.cs(root.isCompact ? 9 : 10) : (root.isCompact ? 9 : 10)
                            buttonIcon: "󰒭"
                            iconFontSize: barWindow ? barWindow.cs(root.isCompact ? 7 : 8) : (root.isCompact ? 7 : 8)
                            accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
                            bgOpacity: 0 // local icon-only media controls
                            textColor: isHoveredOrHighlighted ? ThemeBackend.text : (root.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2)
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: if (player && player.canGoNext) player.next()
                        }
                    }
                }
            }
        }
    }

    Component {
        id: verticalBody

        Item {
            MouseArea {
                id: widgetMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    let targetItem = module ? module : root;
                    let pt = targetItem.mapToItem(null, 0, 0);
                    let globX = root.isRightBar ? pt.x : (pt.x + targetItem.width);
                    let globY = pt.y + (targetItem.height / 2);
                    SideMusicController.itemEntered(barWindow ? barWindow.screen : null, globX, globY, root.isRightBar, false, true);
                }
                onExited: {
                    SideMusicController.itemExited();
                }
                onClicked: {
                    let targetItem = module ? module : root;
                    let pt = targetItem.mapToItem(null, 0, 0);
                    let globX = root.isRightBar ? pt.x : (pt.x + targetItem.width);
                    let globY = pt.y + (targetItem.height / 2);
                    SideMusicController.toggle(barWindow ? barWindow.screen : null, globX, globY, root.isRightBar, false, true);
                }
            }

            Column {
                id: baseCol
                anchors.centerIn: parent
                spacing: barWindow ? barWindow.cs(root.isCompact ? 4 : 5) : (root.isCompact ? 4 : 5)

                Rectangle {
                    id: thumbBox
                    visible: root.showIcon
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: barWindow ? barWindow.cs(root.isCompact ? 26 : 28) : (root.isCompact ? 26 : 28)
                    height: barWindow ? barWindow.cs(root.isCompact ? 26 : 28) : (root.isCompact ? 26 : 28)
                    radius: barWindow ? barWindow.cs(root.isCompact ? 7 : 8) : (root.isCompact ? 7 : 8)
                    color: "transparent" // local icon-only vertical media artwork
                    clip: !sideThumbGlass.active

                    GlassFill {
                        id: sideThumbGlass
                        visible: false // local icon-only media artwork
                        anchors.fill: parent
                        radius: parent.radius
                        tintColor: ThemeBackend.surface1
                        tintAmount: 0.3
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰎈"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: barWindow ? barWindow.cs(root.isCompact ? 12 : 13) : (root.isCompact ? 12 : 13)
                        color: root.isCompact ? ThemeBackend.text : ThemeBackend.subtext0
                        visible: !isMediaActive || root.activeArtUrl === ""
                    }

                    BoundedImage {
                        id: sideArtImg
                        anchors.fill: parent
                        source: isMediaActive ? root.activeArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: sideArtImg
                        source: sideArtImg
                        maskEnabled: true
                        maskSource: sideArtMask
                        visible: isMediaActive && root.activeArtUrl !== "" && sideArtImg.status === Image.Ready
                    }

                    Item {
                        id: sideArtMask
                        anchors.fill: parent
                        layer.enabled: true
                        visible: false

                        Rectangle {
                            anchors.fill: parent
                            radius: thumbBox.radius
                            color: "black"
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: ThemeBackend.surface0
                        opacity: 0.15
                        visible: isMediaActive && root.activeArtUrl !== "" && sideArtImg.status === Image.Ready
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (Caching.serpantinumDir) {
                                PanelActions.invoke("toggle", "music", "");
                            }
                        }
                    }
                }

                Column {
                    visible: root.showControls
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: barWindow ? barWindow.cs(root.isCompact ? 3 : 4) : (root.isCompact ? 3 : 4)

                    IconButton {
                        width: barWindow ? barWindow.cs(root.isCompact ? 24 : 26) : (root.isCompact ? 24 : 26)
                        height: barWindow ? barWindow.cs(root.isCompact ? 24 : 26) : (root.isCompact ? 24 : 26)
                        cornerRadius: barWindow ? barWindow.cs(root.isCompact ? 7 : 8) : (root.isCompact ? 7 : 8)
                        buttonIcon: "󰒮"
                        iconFontSize: barWindow ? barWindow.cs(root.isCompact ? 6 : 7) : (root.isCompact ? 6 : 7)
                        accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
                        bgOpacity: 0 // local icon-only media controls
                        textColor: isHoveredOrHighlighted ? ThemeBackend.text : (root.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2)
                        anchors.horizontalCenter: parent.horizontalCenter
                        onClicked: if (targetPlayer && targetPlayer.canGoPrevious) targetPlayer.previous()
                    }

                    IconButton {
                        width: barWindow ? barWindow.cs(root.isCompact ? 26 : 28) : (root.isCompact ? 26 : 28)
                        height: barWindow ? barWindow.cs(root.isCompact ? 26 : 28) : (root.isCompact ? 26 : 28)
                        cornerRadius: barWindow ? barWindow.cs(root.isCompact ? 7 : 8) : (root.isCompact ? 7 : 8)
                        buttonIcon: (isMediaActive && isPlaying) ? "󰏤" : "󰐊"
                        iconFontSize: barWindow ? barWindow.cs(root.isCompact ? 8 : 9) : (root.isCompact ? 8 : 9)
                        accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
                        bgOpacity: 0 // local icon-only media controls
                        textColor: isHoveredOrHighlighted ? ThemeBackend.green : (root.isCompact ? Qt.lighter(ThemeBackend.text, 1.1) : ThemeBackend.text)
                        anchors.horizontalCenter: parent.horizontalCenter
                        onClicked: if (targetPlayer && targetPlayer.canTogglePlaying) targetPlayer.togglePlaying()
                    }

                    IconButton {
                        width: barWindow ? barWindow.cs(root.isCompact ? 24 : 26) : (root.isCompact ? 24 : 26)
                        height: barWindow ? barWindow.cs(root.isCompact ? 24 : 26) : (root.isCompact ? 24 : 26)
                        cornerRadius: barWindow ? barWindow.cs(root.isCompact ? 7 : 8) : (root.isCompact ? 7 : 8)
                        buttonIcon: "󰒭"
                        iconFontSize: barWindow ? barWindow.cs(root.isCompact ? 6 : 7) : (root.isCompact ? 6 : 7)
                        accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
                        bgOpacity: 0 // local icon-only media controls
                        textColor: isHoveredOrHighlighted ? ThemeBackend.text : (root.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2)
                        anchors.horizontalCenter: parent.horizontalCenter
                        onClicked: if (targetPlayer && targetPlayer.canGoNext) targetPlayer.next()
                    }
                }
            }
        }
    }
}
