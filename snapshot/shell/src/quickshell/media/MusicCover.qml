import QtQuick
import QtCore
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import "../"
Item {
    id: coverHost
    objectName: "playerVinyl"
    required property var root
    readonly property real artworkOffsetY: root.s(16) // local artwork position
    Layout.preferredWidth: root.s(226)
    Layout.preferredHeight: root.s(coverHost.coverMode ? 272 : 250) // lower the cover card by 10 px
    Layout.minimumHeight: coverHost.coverMode ? root.s(272) : 0
    Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
    opacity: root.introCover
    // local vinyl / cover-photo switch v1
    // local persistent artwork choice v1
    property alias coverMode: artworkPreferences.coverMode
    Settings {
        id: artworkPreferences
        location: "file://" + Caching.stateDir + "/media-artwork.ini"
        category: "MediaPlayer"
        property bool coverMode: false
    }
    readonly property string artworkSource: root.activeArtUrl ? (root.activeArtUrl.startsWith("file://") || root.activeArtUrl.startsWith("http") ? root.activeArtUrl : "file://" + root.activeArtUrl) : ""

    function toggleArtworkMode() {
        coverMode = !coverMode;
        artworkPreferences.setValue("coverMode", coverMode);
        artworkPreferences.sync();
    }

    property bool playing: root.active && !!root.targetPlayer && root.targetPlayer.isPlaying
    Rectangle {
        id: vinyl
        objectName: "playerVinylDisc"
        opacity: coverHost.coverMode ? 0 : 1
        visible: opacity > 0.001
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        width: root.s(216)
        height: width
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -coverHost.artworkOffsetY
        radius: width / 2
        color: "#111214"
        border.width: 1
        border.color: "#323438"
        NumberAnimation on rotation {
            objectName: "playerVinylSpin"
            from: 0; to: 360; duration: 18000
            loops: Animation.Infinite
            running: true
            paused: !coverHost.playing || coverHost.coverMode
        }
        Repeater {
            model: 30
            Rectangle {
                required property int index
                anchors.centerIn: parent
                width: parent.width * (0.38 + index * 0.0195)
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, index % 3 === 0 ? 0.085 : 0.035)
                antialiasing: true
            }
        }
        Canvas {
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                let ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                let cx = width / 2, cy = height / 2;
                for (let side = 0; side < 2; side++) {
                    let a = -0.9 + side * Math.PI;
                    for (let i = 0; i < 32; i++) {
                        ctx.beginPath();
                        ctx.moveTo(cx, cy);
                        ctx.arc(cx, cy, width * 0.494, a + i * 0.018, a + (i + 1) * 0.018);
                        ctx.closePath();
                        ctx.fillStyle = Qt.rgba(0.85, 0.87, 0.9, Math.sin(i / 32 * Math.PI) * 0.14);
                        ctx.fill();
                    }
                }
            }
        }
        Rectangle {
            id: label
            anchors.centerIn: parent
            width: parent.width * 0.43
            height: width
            radius: width / 2
            color: ThemeBackend.mauve
            Image {
                id: albumArt
                anchors.fill: parent
                source: coverHost.artworkSource
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                layer.enabled: true
                layer.effect: MultiEffect { maskEnabled: true; maskSource: labelMask }
            }
            Rectangle { id: labelMask; anchors.fill: parent; radius: width / 2; visible: false; layer.enabled: true }
            Rectangle { anchors.centerIn: parent; width: root.s(12); height: width; radius: width / 2; color: "#111214"; border.width: 1; border.color: "#777777" }
        }
    }
    // local persistent cover caption v3
    Rectangle {
        id: coverPhotoFrame
        objectName: "playerCoverPhoto"
        width: root.s(184)
        height: root.s(226)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 0
        radius: root.s(16)
        color: Qt.tint(ThemeBackend.base, Qt.alpha(ThemeBackend.text, 0.22))
        border.width: root.s(1)
        border.color: Qt.alpha(ThemeBackend.text, 0.22)
        antialiasing: true
        opacity: coverHost.coverMode ? 1 : 0
        visible: opacity > 0.001
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Accessible.role: Accessible.Graphic
        Accessible.name: "Current media cover: " + coverTitle.text + ", " + coverArtist.text

        Item {
            id: coverCardContent
            anchors.fill: parent
            anchors.margins: root.s(4)
            Image {
                id: fullCoverArt
                objectName: "playerFullCoverArt"
                anchors.top: parent.top
                width: parent.width
                height: width
                source: coverHost.artworkSource
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software
                layer.effect: MultiEffect { maskEnabled: true; maskSource: fullCoverMask }
            }
            Rectangle {
                objectName: "playerCoverDimmer"
                anchors.fill: fullCoverArt
                color: "black"
                opacity: 0.18
                radius: root.s(12)
                visible: fullCoverArt.status === Image.Ready
            }
            Item {
                id: coverCaption
                objectName: "playerCoverCaption"
                anchors.top: fullCoverArt.bottom
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                Column {
                    anchors.centerIn: parent
                    width: parent.width - root.s(10)
                    spacing: root.s(1)
                Text {
                    id: coverTitle
                    objectName: "playerCoverTitle"
                    width: parent.width
                    text: coverHost.root.targetPlayer && coverHost.root.targetPlayer.trackTitle
                        ? coverHost.root.targetPlayer.trackTitle
                        : (typeof I18n !== "undefined" ? I18n.t("music.nothing_playing") : "Nothing is playing")
                    textFormat: Text.PlainText
                    font.family: "sans-serif"
                    font.pixelSize: root.s(14)
                    font.weight: Font.Normal
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: root.s(11)
                    color: ThemeBackend.text
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
                Text {
                    id: coverArtist
                    objectName: "playerCoverArtist"
                    width: parent.width
                    text: coverHost.root.targetPlayer && coverHost.root.targetPlayer.trackArtist
                        ? coverHost.root.targetPlayer.trackArtist
                        : (typeof I18n !== "undefined" ? I18n.t("music.unknown_artist") : "Unknown artist")
                    textFormat: Text.PlainText
                    font.family: "sans-serif"
                    font.pixelSize: root.s(13)
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: root.s(11)
                    color: Qt.alpha(ThemeBackend.text, 0.85)
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
                }
                MouseArea { id: captionMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                ToolTip.visible: captionMouse.containsMouse && (coverTitle.truncated || coverArtist.truncated)
                ToolTip.delay: 500
                ToolTip.text: coverTitle.text + "\n" + coverArtist.text
            }
            Column {
                x: (parent.width - width) / 2
                y: (fullCoverArt.height - height) / 2
                spacing: root.s(8)
                visible: fullCoverArt.status !== Image.Ready
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "♪"
                    font.pixelSize: root.s(40)
                    color: ThemeBackend.subtext0
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No cover art"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: root.s(11)
                    color: ThemeBackend.subtext0
                }
            }
        }
        Rectangle {
            id: fullCoverMask
            width: fullCoverArt.width
            height: fullCoverArt.height
            radius: root.s(12)
            color: "white"
            visible: false
            layer.enabled: true
        }
    }
    Image {
        id: tonearm
        objectName: "playerTonearm"
        opacity: coverHost.coverMode ? 0 : 1
        visible: opacity > 0.001
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        z: 5
        // The PNG has transparent padding; its pivot is at 50%, 24%.
        source: "file://" + Caching.serpantinumDir + "/assets/media/vinyl_arm.png"
        width: root.s(160)
        height: width
        x: parent.width - width * 0.66
        y: coverHost.artworkOffsetY
        fillMode: Image.PreserveAspectFit
        smooth: true
        transform: Rotation {
            origin.x: tonearm.width * 0.5
            origin.y: tonearm.height * 0.24
            angle: coverHost.playing ? 20 : 0
            Behavior on angle { NumberAnimation { duration: 650; easing.type: Easing.InOutCubic } }
        }
    }
    Rectangle {
        id: coverModeButton
        objectName: "playerArtworkModeButton"
        z: 10
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: root.s(2)
        width: root.s(30)
        height: width
        radius: root.s(8)
        color: buttonMouse.containsMouse ? Qt.alpha(ThemeBackend.text, 0.15) : Qt.alpha(ThemeBackend.text, 0.06)
        border.width: 1
        border.color: Qt.alpha(ThemeBackend.text, activeFocus ? 0.75 : (buttonMouse.containsMouse ? 0.45 : 0.22))
        scale: buttonMouse.pressed ? 0.92 : 1
        activeFocusOnTab: true
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        Accessible.role: Accessible.Button
        Accessible.name: coverHost.coverMode ? "Switch to vinyl" : "Switch to cover photo"
        Accessible.onPressAction: coverHost.toggleArtworkMode()
        Keys.onSpacePressed: event => { coverHost.toggleArtworkMode(); event.accepted = true; }
        Keys.onReturnPressed: event => { coverHost.toggleArtworkMode(); event.accepted = true; }
        Keys.onEnterPressed: event => { coverHost.toggleArtworkMode(); event.accepted = true; }
        ToolTip.visible: buttonMouse.containsMouse
        ToolTip.delay: 500
        ToolTip.text: coverHost.coverMode ? "Switch to vinyl" : "Switch to cover photo"

        // A small disc icon, independent of the installed icon font.
        Rectangle {
            anchors.centerIn: parent
            width: root.s(18)
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: ThemeBackend.text
            antialiasing: true
            Rectangle {
                anchors.centerIn: parent
                width: root.s(10)
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Qt.alpha(ThemeBackend.text, 0.35)
                antialiasing: true
            }
            Rectangle {
                anchors.centerIn: parent
                width: root.s(4)
                height: width
                radius: width / 2
                color: ThemeBackend.text
                antialiasing: true
            }
        }
        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                coverModeButton.forceActiveFocus();
                coverHost.toggleArtworkMode();
            }
        }
    }
}
