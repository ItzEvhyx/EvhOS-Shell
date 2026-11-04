import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Services.Mpris
import "../../../"
import "../../../reusables"
import "../../../reusables/inputs"

Item {
    id: root
    property string variant: "open"
    property var ctx: null
    property bool subscribed: false
    readonly property var player: MprisController.activePlayer
    readonly property bool mediaActive: player !== null && player.playbackState !== MprisPlaybackState.Stopped && player.trackTitle !== ""

    function syncLyrics() {
        if (visible && !subscribed) { Lyrics.subscribe(); subscribed = true; }
        else if (!visible && subscribed) { Lyrics.unsubscribe(); subscribed = false; }
    }
    function timeString(seconds) {
        let n = Math.floor(seconds || 0);
        return Math.floor(n / 60) + ":" + (n % 60 < 10 ? "0" : "") + n % 60;
    }
    onVisibleChanged: syncLyrics()
    Component.onCompleted: syncLyrics()
    Component.onDestruction: if (subscribed) Lyrics.unsubscribe()

    Rectangle {
        id: cover
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: Math.min(parent.width * 0.54, parent.height * 0.38)
        height: width
        radius: width / 2
        color: "#202127"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.16)
        antialiasing: true
        NumberAnimation on rotation {
            from: 0; to: 360; duration: 25000
            loops: Animation.Infinite
            running: root.visible
            paused: root.visible && !(root.player && root.player.isPlaying)
        }
        clip: true
        Text {
            anchors.centerIn: parent
            text: "󰎈"
            font.family: ThemeBackend.iconFont
            font.pixelSize: 56
            color: "#b9bbc1"
        }
        Rectangle {
            id: coverMask
            anchors.fill: parent
            radius: cover.radius
            visible: false
            layer.enabled: true
        }
        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.effect: MultiEffect { maskEnabled: true; maskSource: coverMask }
            BoundedImage {
                anchors.fill: parent
                source: root.mediaActive && MprisController.artUrl ? (MprisController.artUrl.startsWith("file://") || MprisController.artUrl.startsWith("http") ? MprisController.artUrl : "file://" + MprisController.artUrl) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }
        Repeater {
            model: [0.92, 0.84, 0.76, 0.68, 0.60, 0.52, 0.44]
            Rectangle {
                required property real modelData
                required property int index
                anchors.centerIn: parent
                width: cover.width * modelData; height: width; radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: index % 2 ? "#000000" : "#ffffff"
                opacity: index % 2 ? 0.12 : 0.09
                antialiasing: true
            }
        }
        Rectangle {
            anchors.centerIn: parent
            width: cover.width * 0.28; height: width; radius: width / 2
            color: "#1b1c21"
            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.22)
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.68; height: width; radius: width / 2
                color: "#656670"
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.18)
                Rectangle { anchors.centerIn: parent; width: parent.width * 0.38; height: width; radius: width / 2; color: "#101116" }
            }
        }
    }

    Column {
        id: metadata
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: cover.bottom
        anchors.topMargin: 18
        spacing: 4
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.mediaActive ? (MprisController.trackTitle || "Unknown track") : I18n.t("music.nothing_playing")
            font.family: ThemeBackend.fontFamily
            font.pixelSize: 23
            font.weight: Font.Bold
            color: "#ffffff"
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.mediaActive ? (MprisController.trackArtist || "Unknown artist") : ""
            font.family: ThemeBackend.fontFamily
            font.pixelSize: 14
            color: "#c2c2ca"
            elide: Text.ElideRight
        }
    }

    RowLayout {
        id: seek
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: metadata.bottom
        anchors.topMargin: 12
        spacing: 10
        visible: root.mediaActive
        Text { text: root.timeString(MprisController.livePosition); color: "#b9b9c0"; font.pixelSize: 12 }
        WavySeekBar {
            Layout.fillWidth: true
            Layout.preferredHeight: 18
            from: 0
            to: root.player ? Math.max(1, root.player.length) : 1
            value: MprisController.livePosition
            playing: root.player ? root.player.isPlaying : false
            waveColor: "#ffffff"
            onMoved: val => { if (root.player && root.player.canSeek) root.player.position = val; }
        }
        Text { text: root.player ? root.timeString(root.player.length) : "0:00"; color: "#b9b9c0"; font.pixelSize: 12 }
    }

    Row {
        id: controls
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: seek.bottom
        anchors.topMargin: 10
        spacing: 14
        visible: root.mediaActive
        IconButton {
            width: 54; height: 54; cornerRadius: 27
            anchors.verticalCenter: parent.verticalCenter
            buttonIcon: "󰒮"; iconFontSize: 22
            accentColor: ThemeBackend.surface1; bgOpacity: 0.5; textColor: "#ffffff"
            onClicked: if (root.player && root.player.canGoPrevious) root.player.previous()
        }
        IconButton {
            width: 60; height: 60; cornerRadius: 30
            anchors.verticalCenter: parent.verticalCenter
            buttonIcon: MprisController.isPlaying ? "󰏤" : "󰐊"; iconFontSize: 24
            accentColor: "#f1f1f4"; bgOpacity: 1; textColor: "#19191c"
            onClicked: if (root.player && root.player.canTogglePlaying) root.player.togglePlaying()
        }
        IconButton {
            width: 54; height: 54; cornerRadius: 27
            anchors.verticalCenter: parent.verticalCenter
            buttonIcon: "󰒭"; iconFontSize: 22
            accentColor: ThemeBackend.surface1; bgOpacity: 0.5; textColor: "#ffffff"
            onClicked: if (root.player && root.player.canGoNext) root.player.next()
        }
    }

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: controls.bottom
        anchors.topMargin: 16
        anchors.bottom: parent.bottom
        clip: true
        LyricsView {
            anchors.fill: parent
            visible: root.mediaActive && Lyrics.hasLyrics
            alignment: "left"
            centerRatio: 0.28
            linesBehind: 2
            linesAfter: 3
            sideMargin: 0
            baseActiveFont: 20
            lineHeight: 29
            lineSpacing: 5
            activeLineColor: "#ffffff"
            inactiveLineColor: "#ffffff"
            inactiveOpacity: 0.48
            fontFamily: ThemeBackend.fontFamily
        }
        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 12
            visible: !(root.mediaActive && Lyrics.hasLyrics)
            text: !root.mediaActive ? "" : (Lyrics.loading ? I18n.t("music.searching_lyrics") : I18n.t("music.no_lyrics"))
            color: "#b9b9c0"
            font.family: ThemeBackend.fontFamily
            font.pixelSize: 14
        }
    }
}
