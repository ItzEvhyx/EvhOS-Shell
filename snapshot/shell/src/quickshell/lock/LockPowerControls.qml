import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import Quickshell.Io
import "../"
import "../reusables"

Item {
    id: controls
    required property var screenRoot

    anchors.fill: parent

    Item {
        id: bottomInfoTray
        anchors.bottom: parent.bottom
        anchors.bottomMargin: screenRoot.s(16)
        anchors.left: parent.left
        anchors.leftMargin: screenRoot.s(20)
        anchors.right: parent.right
        anchors.rightMargin: screenRoot.s(20)
        height: screenRoot.s(48)

        opacity: screenRoot.inputActive ? 1.0 : 0.0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

        WallpaperBlur {
            z: -1
            anchors.fill: powerControlToggle
            radius: ThemeBackend.borderRadius
            screenOverride: screenRoot.surface.screen
            useSnapshot: true
            standalone: true
            surfaceEnabled: ThemeBackend.liquidGlass
        }

        IconButton {
            id: powerControlToggle
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            size: screenRoot.s(48)
            cornerRadius: ThemeBackend.borderRadius
            buttonIcon: screenRoot.powerMenuOpen ? "󰅖" : "󰐥"
            iconFontSize: screenRoot.s(20)
            accentColor: screenRoot.powerMenuOpen ? ThemeBackend.surface2 : Qt.lighter(ThemeBackend.surface0, 1.28)
            textColor: screenRoot.powerMenuOpen ? ThemeBackend.text : ThemeBackend.red
            onClicked: screenRoot.powerMenuOpen = !screenRoot.powerMenuOpen
        }
    }

    Rectangle {
        id: volumeControl
        anchors.right: bottomInfoTray.right
        anchors.bottom: bottomInfoTray.top
        anchors.bottomMargin: screenRoot.s(12)
        width: screenRoot.s(48)
        height: screenRoot.s(220)
        radius: width / 2
        color: Qt.rgba(0.11, 0.11, 0.13, 0.96)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.10)
        opacity: screenRoot.inputActive && !screenRoot.powerMenuOpen ? 1 : 0
        visible: opacity > 0.01
        enabled: visible && !!Audio.defaultSink && !!Audio.defaultSink.audio
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        readonly property real volume: Audio.defaultSink && Audio.defaultSink.audio ? Audio.defaultSink.audio.volume * 100 : 0
        readonly property bool muted: Audio.defaultSink && Audio.defaultSink.audio ? Audio.defaultSink.audio.muted : false

        ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: screenRoot.s(12)
            anchors.bottomMargin: screenRoot.s(6)
            spacing: screenRoot.s(7)

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: volumeControl.muted ? "0%" : Math.round(volumeControl.volume) + "%"
                color: "#dedee3"
                font.family: ThemeBackend.fontFamily
                font.pixelSize: screenRoot.s(11)
                font.weight: Font.Medium
            }

            Item {
                Layout.fillHeight: true
                Layout.fillWidth: true
                SliderProgress {
                    id: volumeSlider
                    anchors.centerIn: parent
                    width: parent.height - screenRoot.s(10)
                    height: screenRoot.s(12)
                    rotation: -90
                    from: 0
                    to: 100
                    backgroundColor: "#55565d"
                    gradColor1: "#f1f1f4"
                    gradColor2: "#f1f1f4"
                    gradColor3: "#f1f1f4"
                    glowOpacity: 0
                    onMoved: val => {
                        if (!Audio.defaultSink || !Audio.defaultSink.audio) return;
                        if (Audio.defaultSink.audio.muted) Audio.defaultSink.audio.muted = false;
                        Audio.setVolume(Audio.defaultSink, val);
                    }
                    Binding {
                        target: volumeSlider
                        property: "value"
                        value: volumeControl.muted ? 0 : Math.min(100, volumeControl.volume)
                        when: !volumeSlider.isDragging
                    }
                }
            }

            IconButton {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: screenRoot.s(36)
                Layout.preferredHeight: screenRoot.s(36)
                cornerRadius: screenRoot.s(18)
                buttonIcon: volumeControl.muted || volumeControl.volume < 1 ? "󰝟" : (volumeControl.volume < 50 ? "󰕿" : "󰕾")
                iconFontSize: screenRoot.s(18)
                accentColor: "transparent"
                textColor: "#ffffff"
                onClicked: if (Audio.defaultSink) Audio.toggleMute(Audio.defaultSink)
            }
        }
    }

    Rectangle {
        id: powerContainer
        z: 100

        Shortcut {
            sequence: "Escape"
            enabled: screenRoot.powerMenuOpen
            onActivated: {
                screenRoot.powerMenuOpen = false;
                screenRoot.restoreFocus();
            }
        }

        anchors.bottom: bottomInfoTray.top
        anchors.bottomMargin: screenRoot.s(16)
        anchors.right: bottomInfoTray.right

        width: screenRoot.s(320)
        height: screenRoot.powerMenuOpen ? (menuLayout.implicitHeight + screenRoot.s(24)) : 0
        radius: ThemeBackend.borderRadius

        clip: true
        visible: height > 0 || opacity > 0
        opacity: screenRoot.powerMenuOpen ? 1.0 : 0.0

        color: Qt.rgba(ThemeBackend.surface0.r, ThemeBackend.surface0.g, ThemeBackend.surface0.b, 0.45 * ThemeBackend.elementOpacity)

        WallpaperBlur {
            z: -1
            anchors.fill: parent
            radius: parent.radius
            screenOverride: screenRoot.surface.screen
            useSnapshot: true
        }

        Behavior on height {
            NumberAnimation {
                duration: 340
                easing.type: Easing.OutBack
                easing.overshoot: 1.15
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutCubic
            }
        }

        ColumnLayout {
            id: menuLayout
            anchors.top: parent.top
            anchors.topMargin: screenRoot.s(12)
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: screenRoot.s(12)
            anchors.rightMargin: screenRoot.s(12)
            spacing: screenRoot.s(8)

            FillButton {
                Layout.fillWidth: true
                buttonIcon: "󰒲"
                buttonText: I18n.t("lock.power.suspend")
                accentColor: ThemeBackend.mauve
                baseColor: ThemeBackend.surface0
                hoverColor: ThemeBackend.surface1
                fillDuration: 1200
                onTriggered: { screenRoot.powerMenuOpen = false; screenRoot.suspendProcess.running = true; }
            }

            FillButton {
                Layout.fillWidth: true
                buttonIcon: "󰑓"
                buttonText: I18n.t("lock.power.reboot")
                accentColor: ThemeBackend.blue
                baseColor: ThemeBackend.surface0
                hoverColor: ThemeBackend.surface1
                fillDuration: 1200
                onTriggered: { screenRoot.powerMenuOpen = false; screenRoot.reloadProcess.running = true; }
            }

            FillButton {
                Layout.fillWidth: true
                buttonIcon: "󰐥"
                buttonText: I18n.t("lock.power.power_off")
                accentColor: ThemeBackend.red
                baseColor: ThemeBackend.surface0
                hoverColor: ThemeBackend.surface1
                fillDuration: 1200
                onTriggered: { screenRoot.powerMenuOpen = false; screenRoot.poweroffProcess.running = true; }
            }
        }
    }
}
