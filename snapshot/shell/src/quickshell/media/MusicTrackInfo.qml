import QtQuick
import QtQuick.Layouts
import "../"
import "../reusables"
ColumnLayout {
    required property var root
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        z: 1
        spacing: root.s(6)
        opacity: root.introText
        transform: Translate { x: root.s(25) * (1 - root.introText) }
        
        MarqueeText {
            Layout.fillWidth: true
            Layout.preferredHeight: root.s(34)
            text: (root.targetPlayer && root.targetPlayer.trackTitle !== "") ? root.targetPlayer.trackTitle : I18n.t("music.nothing_playing")
            color: root.dynamicTextColor
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.s(24)
            font.bold: true
            marqueeSpacing: root.s(50)
            speed: 25
            active: root.active

            Behavior on color { ColorAnimation { duration: 600 } }
        }

        Text {
            text: root.targetPlayer && root.targetPlayer.trackArtist ? I18n.t("music.by_artist", { "artist": root.targetPlayer.trackArtist }) : I18n.t("music.by_artist", { "artist": I18n.t("music.unknown_artist") })
            color: root.dynamicTextColor
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.s(13.5)
            font.bold: true
            elide: Text.ElideRight
            maximumLineCount: 1
            Layout.fillWidth: true
            Layout.preferredHeight: root.s(18)
        }
    }
}
