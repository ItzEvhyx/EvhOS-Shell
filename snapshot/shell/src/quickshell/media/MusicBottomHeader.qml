import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import "../"
import "../reusables"

RowLayout {
    id: bottomHeader
    required property var root
    property alias bottomSectionSwitch: bottomSectionSwitch

    Layout.fillWidth: true
    opacity: root.introEqHeader
    transform: Translate { y: root.s(12) * (1 - root.introEqHeader) }

    Item {
        id: bottomSectionSwitch
        property int currentIndex: 0
        readonly property var options: [
            typeof I18n !== "undefined" ? I18n.t("music.equalizer", "Equalizer") : "Equalizer",
            typeof I18n !== "undefined" ? I18n.t("music.audio.title", "Audio") : "Audio",
            typeof I18n !== "undefined" ? I18n.t("music.lyrics", "Lyrics") : "Lyrics",
            "Queue"
        ]
        Layout.preferredHeight: root.s(30)
        Layout.preferredWidth: tabsRow.implicitWidth
        implicitWidth: tabsRow.implicitWidth
        implicitHeight: root.s(30)
        onCurrentIndexChanged: {
            if (currentIndex !== 1 && root.audioTestRunning) {
                root.toggleAudioTest();
            }
            root.updateLyricsSubscription();
            if (currentIndex === 2 || currentIndex === 3) {
                root.toEqAnim.stop();
                root.toAudioAnim.stop();
                root.toLyricsAnim.restart();
                root.restoreLastSavedEqualizer();
            } else if (currentIndex === 1) {
                root.toEqAnim.stop();
                root.toLyricsAnim.stop();
                root.toAudioAnim.restart();
                root.playAudioIntro();
                root.restoreLastSavedEqualizer();
            } else {
                root.toLyricsAnim.stop();
                root.toAudioAnim.stop();
                root.restoreLastSavedEqualizer();
                root.toEqAnim.restart();
            }
        }
        Row {
            id: tabsRow
            anchors.fill: parent
            spacing: root.s(16)
            Repeater {
                model: bottomSectionSwitch.options
                delegate: Item {
                    id: tab
                    required property int index
                    required property string modelData
                    width: tabLabel.implicitWidth
                    height: tabsRow.height
                    Text {
                        id: tabLabel
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -root.s(2)
                        text: tab.modelData
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.s(11.5)
                        font.weight: bottomSectionSwitch.currentIndex === tab.index ? Font.DemiBold : Font.Normal
                        color: bottomSectionSwitch.currentIndex === tab.index || tabMouse.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        height: root.s(2)
                        radius: height / 2
                        color: ThemeBackend.mauve
                        opacity: bottomSectionSwitch.currentIndex === tab.index ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }
                    MouseArea {
                        id: tabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: bottomSectionSwitch.currentIndex = tab.index
                    }
                }
            }
        }
    }

    Item { Layout.fillWidth: true }

    ClickButton {
        id: audioTestBtn
        Layout.preferredHeight: root.s(26)
        Layout.preferredWidth: root.audioTestBtnWidth * root.audioHeaderProgress
        implicitWidth: Layout.preferredWidth
        visible: root.audioHeaderProgress > 0.01
        opacity: root.audioHeaderProgress
        clip: true
        cornerRadius: root.s(12)
        horizontalPadding: root.s(8)
        buttonIcon: root.audioTestRunning ? "󰓛" : "󰋋"
        buttonText: root.audioTestRunning
            ? (typeof I18n !== "undefined" ? I18n.t("music.audio.stop_test", "Stop") : "Stop")
            : (typeof I18n !== "undefined" ? I18n.t("music.audio.test", "Test") : "Test")
        textFontSize: root.s(11.5)
        iconFontSize: root.s(12)
        accentColor: root.audioTestRunning
            ? (ThemeBackend.mauve || "#cba6f7")
            : (ThemeBackend.surface0 || "#313244")
        bgOpacity: root.audioTestRunning ? 0.8 : 0.35
        textColor: root.audioTestRunning
            ? (ThemeBackend.base || "#1e1e2e")
            : (ThemeBackend.text || "#cdd6f4")
        onClicked: root.toggleAudioTest()
    }

    ClickButton {
        id: actionBtn
        visible: bottomSectionSwitch.currentIndex !== 3
        Layout.preferredHeight: root.s(26)
        Layout.preferredWidth: visible ? root.actionBtnCurrentWidth : 0
        implicitWidth: root.actionBtnCurrentWidth
        cornerRadius: root.s(12)
        horizontalPadding: root.s(12)
        buttonIcon: bottomSectionSwitch.currentIndex === 2
            ? "󰈔"
            : (bottomSectionSwitch.currentIndex === 1 ? "󰑐" : "")
        buttonText: {
            if (bottomSectionSwitch.currentIndex === 2) {
                return typeof I18n !== "undefined" ? I18n.t("music.select_local_file", "Select file") : "Select file";
            }
            if (bottomSectionSwitch.currentIndex === 1) {
                return typeof I18n !== "undefined" ? I18n.t("music.audio.reset", "Reset") : "Reset";
            }
            return root.eqData && root.eqData.pending ? I18n.t("music.eq.apply") : I18n.t("music.eq.saved");
        }
        textFontSize: root.s(11.5)
        iconFontSize: root.s(13)
        accentColor: {
            if (bottomSectionSwitch.currentIndex !== 0) {
                return ThemeBackend.surface0 || "#313244";
            }
            return root.eqData && root.eqData.pending ? (ThemeBackend.mauve || "#cba6f7") : (ThemeBackend.surface0 || "#313244");
        }
        bgOpacity: bottomSectionSwitch.currentIndex === 0 && !(root.eqData && root.eqData.pending) ? 0 : 0.35
        textColor: {
            if (bottomSectionSwitch.currentIndex !== 0) {
                return ThemeBackend.text || "#cdd6f4";
            }
            return root.eqData && root.eqData.pending ? (ThemeBackend.base || "#1e1e2e") : (ThemeBackend.text || "#cdd6f4");
        }
        enabled: bottomSectionSwitch.currentIndex === 2
            ? (root.hasTargetPlayer && !Lyrics.loading)
            : (bottomSectionSwitch.currentIndex === 1
                ? (Math.abs(root.balanceSlider.value) >= 0.005 || root.eqData.mono === true || root.eqData.swap === true || String(root.eqData.dynamics || "off") !== "off")
                : true)
        opacity: bottomSectionSwitch.currentIndex === 2
            ? (root.hasTargetPlayer && !Lyrics.loading ? 1.0 : 0.45)
            : (bottomSectionSwitch.currentIndex === 1
                ? (enabled ? 1.0 : 0.45)
                : 1.0)
        Behavior on opacity { NumberAnimation { duration: 250 } }
        Behavior on accentColor { ColorAnimation { duration: 250 } }
        Behavior on textColor { ColorAnimation { duration: 250 } }
        onClicked: {
            if (bottomSectionSwitch.currentIndex === 2) {
                root.lyricsPickerPopup.targetScreen = (root.Window && root.Window.window) ? root.Window.window.screen : null;
                root.lyricsPickerPopup.openPicker();
            } else if (bottomSectionSwitch.currentIndex === 1) {
                root.resetAudio();
            } else if (root.eqData && root.eqData.pending) {
                var temp = Object.assign({}, root.eqData);
                temp.pending = false;
                root.eqData = temp;
                root.savedEqData = Object.assign({}, temp);
                root.lastEqUpdate = Date.now();
                root.triggerEqLightning();
                root.execCmd(Caching.qsDir + "/media/equalizer.sh apply");
            }
        }
    }

    Item {
        id: presetTextContainer
        Layout.preferredHeight: root.s(26)
        Layout.preferredWidth: (presetLabelText.implicitWidth + root.s(12)) * Math.max(0.0, 1.0 - root.presetSlideProgress)
        implicitWidth: Layout.preferredWidth
        visible: bottomSectionSwitch.currentIndex === 0 && root.presetSlideProgress < 0.99
        opacity: Math.max(0.0, 1.0 - root.presetSlideProgress)
        clip: true

        Text {
            id: presetLabelText
            anchors.verticalCenter: parent.verticalCenter
            x: root.s(12) + (root.s(24) * root.presetSlideProgress)
            text: root.eqData && root.eqData.preset ? I18n.t("music.presets." + root.eqData.preset.toLowerCase()) : I18n.t("music.presets.flat")
            color: ThemeBackend.subtext0 || "#a6adc8"
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.s(13)
            font.bold: true
        }
    }
}
