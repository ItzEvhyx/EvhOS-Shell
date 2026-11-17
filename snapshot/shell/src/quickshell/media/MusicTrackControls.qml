import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import "../"
import "../reusables"
import "../reusables/media"

ColumnLayout {
    id: controls
    required property var root
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    Layout.alignment: Qt.AlignVCenter
    Layout.topMargin: 0
    spacing: root.s(4)

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: root.s(20)
        opacity: root.introControls
        transform: Translate { y: root.s(18) * (1 - root.introControls) }

        IconButton {
            id: prevMediaBtn
            Layout.preferredWidth: root.s(32)
            Layout.preferredHeight: root.s(32)
            cornerRadius: root.s(16)
            buttonIcon: "󰒮"
            iconFontSize: root.s(16)
            accentColor: ThemeBackend.text
            bgOpacity: isHoveredOrHighlighted ? 0.25 : 0.0
            textColor: isHoveredOrHighlighted ? ThemeBackend.text : Qt.alpha(ThemeBackend.text, 0.78)
            Layout.alignment: Qt.AlignVCenter
            onClicked: if (root.targetPlayer && root.targetPlayer.canGoPrevious) root.targetPlayer.previous()
        }

        IconButton {
            id: playPauseBtn
            Layout.preferredWidth: root.s(43)
            Layout.preferredHeight: root.s(43)
            cornerRadius: root.s(22)
            buttonIcon: (root.targetPlayer && root.targetPlayer.isPlaying) ? "󰏤" : "󰐊"
            iconFontSize: root.s(20)
            accentColor: ThemeBackend.text
            bgOpacity: isHoveredOrHighlighted ? 0.38 : 0.25
            textColor: ThemeBackend.text
            Layout.alignment: Qt.AlignVCenter
            onClicked: if (root.targetPlayer && root.targetPlayer.canTogglePlaying) root.targetPlayer.togglePlaying()
        }

        IconButton {
            id: nextMediaBtn
            Layout.preferredWidth: root.s(32)
            Layout.preferredHeight: root.s(32)
            cornerRadius: root.s(16)
            buttonIcon: "󰒭"
            iconFontSize: root.s(16)
            accentColor: ThemeBackend.text
            bgOpacity: isHoveredOrHighlighted ? 0.25 : 0.0
            textColor: isHoveredOrHighlighted ? ThemeBackend.text : Qt.alpha(ThemeBackend.text, 0.78)
            Layout.alignment: Qt.AlignVCenter
            onClicked: if (root.targetPlayer && root.targetPlayer.canGoNext) root.targetPlayer.next()
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 0
        spacing: root.s(2)
        opacity: root.introControls
        transform: Translate { x: root.s(18) * (1 - root.introControls); y: root.s(9) * (1 - root.introControls) }

        WavySeekBar {
            id: progBar
            objectName: "playerSeekBar"
            Layout.fillWidth: true
            Layout.preferredHeight: root.s(50)
            Layout.topMargin: -root.s(5)
            Layout.bottomMargin: -root.s(2)
            Layout.alignment: Qt.AlignVCenter
            from: 0.0
            to: root.targetPlayer ? Math.max(0, root.targetPlayer.length) : 0.0
            enabled: !!root.targetPlayer && root.targetPlayer.canSeek && to > 0
            Binding { target: progBar; property: "value"; value: root.currentLivePosition; when: !progBar.isDragging && !progBar.seekPending; restoreMode: Binding.RestoreBindingOrValue }
            value: root.currentLivePosition
            playing: root.targetPlayer ? root.targetPlayer.isPlaying : false
            waveColor: ThemeBackend.mauve || "#cba6f7"

            property bool seekPending: false

            Timer {
                id: seekTimer
                interval: 1000
                onTriggered: progBar.seekPending = false
            }

            Connections {
                target: root.targetPlayer
                function onPositionChanged() {
                    if (!root.active) return;
                    if (!progBar.isDragging && !progBar.seekPending && root.targetPlayer) {
                        progBar.value = root.targetPlayer.position;
                    }
                }
            }

            onMoved: val => {
                if (root.targetPlayer && root.targetPlayer.canSeek) {
                    progBar.seekPending = true;
                    seekTimer.restart();
                    progBar.value = val;
                    root.targetPlayer.position = val;
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Text { 
                text: root.formatTime(root.currentLivePosition); 
                color: root.dynamicTextColor; 
                font.family: ThemeBackend.fontFamily; 
                font.bold: true; 
                font.pixelSize: root.s(12); 
                Behavior on color { ColorAnimation { duration: 600 } }
            }
            Item { Layout.fillWidth: true }
            Text { 
                text: root.formatTime(root.targetPlayer ? root.targetPlayer.length : 0); 
                color: root.dynamicTextColor; 
                font.family: ThemeBackend.fontFamily; 
                font.bold: true; 
                font.pixelSize: root.s(12); 
                Behavior on color { ColorAnimation { duration: 600 } }
            }
        }
    }

}
