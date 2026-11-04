import "." as GuideScroll
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "../reusables"

GuideTab {
    id: aboutTabRoot

    function activateTab() {
        if (typeof SystemInfo !== "undefined") {
            SystemInfo.fetch();
        }
    }

    onVisibleChanged: {
        if (visible) activateTab();
    }

    Component.onCompleted: {
        if (visible) activateTab();
    }

    Flickable {

        GuideScroll.MouseWheelScroll {}
        anchors.fill: parent
        contentWidth: width
        contentHeight: mainCol.implicitHeight + rootObj.s(32)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: mainCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: rootObj.s(24)
            anchors.rightMargin: rootObj.s(24)
            anchors.topMargin: rootObj.s(16)
            spacing: rootObj.s(24)

            Item {
                id: headerArea
                Layout.fillWidth: true
                Layout.topMargin: rootObj.s(12)
                Layout.bottomMargin: rootObj.s(8)
                implicitHeight: brandingContainer.implicitHeight

                readonly property real brandingW: rootObj.s(220)
                Item {
                    id: brandingContainer
                    width: headerArea.brandingW
                    implicitHeight: brandingCol.implicitHeight
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter

                    Column {
                        id: brandingCol
                        width: brandingContainer.width
                        anchors.centerIn: parent
                        spacing: rootObj.s(6)

                        Image {
                            id: aboutLogo
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: rootObj.s(205)
                            height: rootObj.s(205)
                            source: "file:///home/yhvhan/Documents/SYSTEM_ASSETS/OS_LOGO.png"
                            sourceSize: Qt.size(768, 768)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            antialiasing: true
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: "EvhOS"
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: rootObj.s(22)
                            color: ThemeBackend.text
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: "v" + (Updater.localVersion !== "..." ? Updater.localVersion : (rootObj.dotsVersion !== "Loading..." && rootObj.dotsVersion !== I18n.t("guide.about.loading") ? rootObj.dotsVersion : "2.0.0"))
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(13)
                            color: ThemeBackend.subtext0
                        }
                    }
                }


            }

            RowLayout {
                Layout.fillWidth: true
                spacing: rootObj.s(16)

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    spacing: rootObj.s(6)

                    Repeater {
                        id: hwRepeater
                        model: [
                            { icon: "󰌢", label: I18n.t("guide.about.hardware.device_name"), value: (typeof SystemInfo !== "undefined" && SystemInfo.hostname !== "") ? SystemInfo.hostname : I18n.t("guide.about.unknown") },
                            { icon: "󰻠", label: I18n.t("guide.about.hardware.processor"), value: (typeof SystemInfo !== "undefined" && SystemInfo.cpuModel !== "") ? SystemInfo.cpuModel + (SystemInfo.cpuCores > 0 ? " (" + SystemInfo.cpuCores + ")" : "") : I18n.t("guide.about.unknown") },
                            { icon: "󰢮", label: I18n.t("guide.about.hardware.graphics"), value: (typeof SystemInfo !== "undefined" && SystemInfo.gpuModel !== "") ? SystemInfo.gpuModel : I18n.t("guide.about.unknown") },
                            { icon: "󰍛", label: I18n.t("guide.about.hardware.memory"), value: (typeof SystemInfo !== "undefined" && SystemInfo.totalRamGb > 0) ? SystemInfo.totalRamGb + " GB" : I18n.t("guide.about.unknown") },
                            { icon: "󰋊", label: I18n.t("guide.about.hardware.disk_capacity"), value: (typeof SystemInfo !== "undefined" && SystemInfo.diskTotalGb > 0) ? SystemInfo.diskUsedGb + " / " + SystemInfo.diskTotalGb + " GB" : I18n.t("guide.about.unknown") }
                        ]

                        Rectangle {
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            implicitHeight: rowHwLayout.implicitHeight + rootObj.s(20)
                            radius: ThemeBackend.borderRadius
                            color: gf1.active ? "transparent" : Qt.alpha(ThemeBackend.surface0, 0.4)

                            GlassFill {
                                id: gf1
                                anchors.fill: parent
                                radius: parent.radius
                                tintColor: Qt.alpha(ThemeBackend.surface0, 0.4)
                                tintAmount: 0.25
                            }

                            RowLayout {
                                id: rowHwLayout
                                anchors.left: parent.left
                                anchors.leftMargin: rootObj.s(14)
                                anchors.right: parent.right
                                anchors.rightMargin: rootObj.s(14)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: rootObj.s(12)

                                IconButton {
                                    enabled: false
                                    size: rootObj.s(32)
                                    Layout.preferredWidth: rootObj.s(32)
                                    Layout.preferredHeight: rootObj.s(32)
                                    Layout.alignment: Qt.AlignVCenter
                                    cornerRadius: ThemeBackend.borderRadius
                                    buttonIcon: modelData.icon
                                    iconFontSize: rootObj.s(16)
                                    accentColor: ThemeBackend.surface0
                                    textColor: "#ffffff"
                                }

                                MarqueeText {
                                    text: modelData.label
                                    font.pixelSize: rootObj.s(12)
                                    color: ThemeBackend.text
                                    Layout.preferredWidth: rootObj.s(105)
                                    Layout.maximumWidth: rootObj.s(105)
                                    horizontalAlignment: Text.AlignLeft
                                    active: aboutTabRoot.visible && (!rootObj || rootObj.visible)
                                    marqueeSpacing: rootObj.s(30)
                                }

                                MarqueeText {
                                    text: modelData.value
                                    font.pixelSize: rootObj.s(12)
                                    color: ThemeBackend.subtext0
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignRight
                                    active: aboutTabRoot.visible && (!rootObj || rootObj.visible)
                                    marqueeSpacing: rootObj.s(30)
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    spacing: rootObj.s(6)

                    Repeater {
                        id: sysRepeater
                        model: [
                            { icon: "⛁", label: I18n.t("guide.about.system.os_name"), value: (typeof SystemInfo !== "undefined" && SystemInfo.osName !== "") ? SystemInfo.osName : I18n.t("guide.about.system.default_os") },
                            { icon: "󰌽", label: I18n.t("guide.about.system.kernel_version"), value: (typeof SystemInfo !== "undefined" && SystemInfo.kernelVersion !== "") ? SystemInfo.kernelVersion : I18n.t("guide.about.unknown") },
                            { icon: "󰧨", label: I18n.t("guide.about.system.desktop"), value: (typeof SystemInfo !== "undefined" && SystemInfo.desktopEnv !== "") ? SystemInfo.desktopEnv : I18n.t("guide.about.unknown") },
                            { icon: "󰆍", label: I18n.t("guide.about.system.shell"), value: (typeof SystemInfo !== "undefined" && SystemInfo.shell !== "") ? SystemInfo.shell : I18n.t("guide.about.unknown") },
                            { icon: "󰔛", label: I18n.t("guide.about.system.uptime"), value: (typeof SystemInfo !== "undefined" && SystemInfo.uptime !== "") ? SystemInfo.uptime : I18n.t("guide.about.unknown") }
                        ]

                        Rectangle {
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            implicitHeight: rowSysLayout.implicitHeight + rootObj.s(20)
                            radius: ThemeBackend.borderRadius
                            color: gf2.active ? "transparent" : Qt.alpha(ThemeBackend.surface0, 0.4)

                            GlassFill {
                                id: gf2
                                anchors.fill: parent
                                radius: parent.radius
                                tintColor: Qt.alpha(ThemeBackend.surface0, 0.4)
                                tintAmount: 0.25
                            }

                            RowLayout {
                                id: rowSysLayout
                                anchors.left: parent.left
                                anchors.leftMargin: rootObj.s(14)
                                anchors.right: parent.right
                                anchors.rightMargin: rootObj.s(14)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: rootObj.s(12)

                                IconButton {
                                    enabled: false
                                    size: rootObj.s(32)
                                    Layout.preferredWidth: rootObj.s(32)
                                    Layout.preferredHeight: rootObj.s(32)
                                    Layout.alignment: Qt.AlignVCenter
                                    cornerRadius: ThemeBackend.borderRadius
                                    buttonIcon: modelData.icon
                                    iconFontSize: rootObj.s(16)
                                    accentColor: ThemeBackend.surface0
                                    textColor: "#ffffff"
                                }

                                MarqueeText {
                                    text: modelData.label
                                    font.pixelSize: rootObj.s(12)
                                    color: ThemeBackend.text
                                    Layout.preferredWidth: rootObj.s(105)
                                    Layout.maximumWidth: rootObj.s(105)
                                    horizontalAlignment: Text.AlignLeft
                                    active: aboutTabRoot.visible && (!rootObj || rootObj.visible)
                                    marqueeSpacing: rootObj.s(30)
                                }

                                MarqueeText {
                                    text: modelData.value
                                    font.pixelSize: rootObj.s(12)
                                    color: ThemeBackend.subtext0
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignRight
                                    active: aboutTabRoot.visible && (!rootObj || rootObj.visible)
                                    marqueeSpacing: rootObj.s(30)
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: rootObj.s(12)

                ClickButton {
                    Layout.preferredWidth: rootObj.s(260)
                    Layout.preferredHeight: rootObj.s(42)
                    horizontalPadding: rootObj.s(14)
                    cornerRadius: ThemeBackend.borderRadius
                    buttonText: "Source code"
                    textFontSize: rootObj.s(13)
                    buttonIcon: "󰊤"
                    iconFontSize: rootObj.s(16)
                    accentColor: ThemeBackend.surface0
                    textColor: ThemeBackend.text

                    onTriggered: Quickshell.execDetached(["xdg-open", "https://github.com/ilyamiro/serpantinum"])
                }
            }
        }
    }
}
