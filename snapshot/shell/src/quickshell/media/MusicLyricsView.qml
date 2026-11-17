import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import "../"
import "../reusables"
import "../reusables/media"

Item {
    id: lyricsView
    required property var root
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: parent.width
    x: 0
    opacity: 1.0
    visible: opacity > 0.0
    clip: true

    Behavior on x { NumberAnimation { duration: 400; easing.type: Easing.OutQuart } }
    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: root.s(8)
        radius: root.s(15)
        color: Qt.alpha(ThemeBackend.text, 0.035)
        border.width: 1
        border.color: Qt.alpha(ThemeBackend.text, 0.07)
    }

    LyricsView {
        id: popupLyricsViewport
        anchors.fill: parent
        anchors.margins: root.s(14)
        anchors.topMargin: root.s(20)
        visible: Lyrics.hasLyrics
        sideMargin: root.s(8)
        baseActiveFont: root.s(17)
        lineHeight: Math.max(root.s(30), baseActiveFont * 1.4)
        lineSpacing: Math.max(root.s(6), baseActiveFont * 0.25)
        activeLineColor: ThemeBackend.text
        inactiveLineColor: ThemeBackend.text || "#cdd6f4"
        fontFamily: ThemeBackend.fontFamily
        fontWeight: Font.DemiBold
        inactiveOpacity: 0.42
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: root.s(6)
        visible: !Lyrics.hasLyrics
        z: 5

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "󰎈"
            font.family: ThemeBackend.iconFont
            font.pixelSize: root.s(28)
            color: root.dynamicTextColor
            opacity: 0.75
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: {
                if (!root.hasTargetPlayer || !root.targetPlayer.trackTitle) return I18n.t("music.nothing_playing");
                if (Lyrics.loading) return I18n.t("music.searching_lyrics");
                return I18n.t("music.no_lyrics");
            }
            font.family: ThemeBackend.fontFamily
            font.weight: Font.DemiBold
            font.pixelSize: root.s(12)
            color: ThemeBackend.subtext0 || "#a6adc8"
        }
    }
}
