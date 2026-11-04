import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import "../"
import "../reusables"

GuideTab {
    id: welcomeTabRoot

    revealed: true

    FontLoader { id: evhosFont; source: "file:///home/yhvhan/.config/serpantinum/assets/Orbitron.ttf" }

    function activateTab() {
        revealed = true;
        logoFillLevel = 0.0;
        logoFillAnim.restart();
    }

    onVisibleChanged: {
        if (visible) activateTab();
    }

    Component.onCompleted: {
        if (visible) activateTab();
    }

    property real titleWavePhase: 0.0
    NumberAnimation on titleWavePhase {
        running: welcomeTabRoot.visible
        loops: Animation.Infinite
        from: 0
        to: Math.PI * 2
        duration: 7000
    }

    component StartButtonContent : Item {
        id: bRoot
        property color textColor: ThemeBackend.blue
        property real fillLevel: 0.0
        property bool isHovered: false

        RowLayout {
            anchors.centerIn: parent
            spacing: rootObj.s(10)

            Text {
                id: iconText
                text: "󰐊"
                font.family: ThemeBackend.iconFont
                font.pixelSize: rootObj.s(18)
                color: bRoot.textColor
                Behavior on color { ColorAnimation { duration: 150 } }

                property real charNorm: 0.15
                property real bump: bRoot.fillLevel > 0.001 && bRoot.fillLevel < 0.999
                                    ? Math.exp(-Math.pow((bRoot.fillLevel - charNorm) * 12, 2))
                                    : 0.0

                transform: [
                    Translate { y: -iconText.bump * rootObj.s(2.5) },
                    Scale { origin.x: width / 2; origin.y: height / 2; xScale: 1.0 + iconText.bump * 0.08; yScale: 1.0 + iconText.bump * 0.08 }
                ]
            }

            Row {
                spacing: 0
                Repeater {
                    model: Array.from(I18n.t("guide.welcome.start_tutorial"))
                    Text {
                        id: charText
                        required property string modelData
                        required property int index

                        text: modelData === " " ? "\u00A0" : modelData
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.Bold
                        font.pixelSize: rootObj.s(14)

                        color: bRoot.textColor
                        Behavior on color { ColorAnimation { duration: 150 } }

                        property real charNorm: 0.25 + (index / 14) * 0.65
                        property real bump: bRoot.fillLevel > 0.001 && bRoot.fillLevel < 0.999
                                            ? Math.exp(-Math.pow((bRoot.fillLevel - charNorm) * 12, 2))
                                            : 0.0

                        transform: [
                            Translate { y: -charText.bump * rootObj.s(2.5) },
                            Scale { origin.x: width / 2; origin.y: height / 2; xScale: 1.0 + charText.bump * 0.08; yScale: 1.0 + charText.bump * 0.08 }
                        ]
                    }
                }
            }
        }
    }

    Connections {
        target: rootObj
        function onActivationCounterChanged() {
            if (welcomeTabRoot.visible) {
                activateTab();
            }
        }
        function onVisibleChanged() {
            if (rootObj && rootObj.visible && welcomeTabRoot.visible) {
                activateTab();
            }
        }
    }

    property real logoFillLevel: 1.15

    NumberAnimation {
        id: logoFillAnim
        target: welcomeTabRoot
        property: "logoFillLevel"
        from: 0.0
        to: 1.15
        duration: 6500
        easing.type: Easing.OutCubic
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: rootObj.s(25)

        Item {
            id: logoContainer
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: rootObj.s(310)
            Layout.preferredHeight: rootObj.s(310)

            Image {
                anchors.fill: parent
                source: "file:///home/yhvhan/Documents/SYSTEM_ASSETS/OS_LOGO.png"
                sourceSize: Qt.size(768, 768)
                fillMode: Image.PreserveAspectFit
                smooth: true
                antialiasing: true
            }

        }

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: rootObj.s(6)

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "EVHOS"
                font.family: evhosFont.status === FontLoader.Ready ? evhosFont.name : "Sans Serif"
                font.weight: Font.DemiBold
                font.pixelSize: rootObj.s(32)
                font.letterSpacing: rootObj.s(5)
                color: ThemeBackend.text
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "—  v" + (Updater.localVersion !== "..." ? Updater.localVersion : (rootObj.dotsVersion !== "Loading..." && rootObj.dotsVersion !== I18n.t("guide.about.loading") ? rootObj.dotsVersion : "2.0.0")) + "  —"
                font.family: evhosFont.status === FontLoader.Ready ? evhosFont.name : "Sans Serif"
                font.pixelSize: rootObj.s(11)
                font.letterSpacing: rootObj.s(2)
                color: ThemeBackend.subtext0
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: rootObj.s(16)

            ClickButton {
                id: aboutBtn
                Layout.preferredWidth: rootObj.s(130)
                Layout.preferredHeight: rootObj.s(48)
                horizontalPadding: rootObj.s(12)
                cornerRadius: rootObj.s(12)
                buttonText: I18n.t("guide.welcome.about")
                textFontSize: rootObj.s(14)
                buttonIcon: ""
                iconFontSize: rootObj.s(16)
                accentColor: ThemeBackend.surface0
                textColor: ThemeBackend.text

                onTriggered: rootObj.gotoTab("About")
            }
        }
    }
}
