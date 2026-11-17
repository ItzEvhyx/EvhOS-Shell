import QtQuick
import QtQuick.Layouts
import "../"
import "../reusables"

Rectangle {
    id: card
    objectName: "asciiWeatherCard"
    required property var root
    radius: root.s(24)
    color: Qt.alpha(ThemeBackend.crust, 0.30)
    border.width: 1
    border.color: Qt.alpha(ThemeBackend.text, hover.hovered ? 0.12 : 0.055)
    Behavior on border.color { ColorAnimation { duration: 250 } }
    HoverHandler { id: hover }
    readonly property var days: root.weatherData && Array.isArray(root.weatherData.forecast) ? root.weatherData.forecast : []
    readonly property var day: days[root.weatherView] || ({})
    readonly property bool offline: !!(root.weatherData && root.weatherData.offline)
    readonly property bool ready: !offline && days.length > 0
    readonly property string icon: root.weatherView===0 && root.weatherData.current_icon ? root.weatherData.current_icon : (day.icon || "")
    function conditionFor(icon) {
        if (icon === "") return "sun";
        if (icon === "") return "moon";
        if (icon === "󰖑") return "fog";
        if (icon === "󰖗") return "rain";
        if (icon === "") return "snow";
        if (icon === "") return "storm";
        return "cloud";
    }
    readonly property string condition: conditionFor(icon)
    readonly property string conditionText: {
        if (offline) return I18n.t("weather.desc.offline");
        if (!ready) return I18n.t("calendar.loading");
        if (root.weatherView !== 0) return day.desc || I18n.t("weather.desc.unknown");
        let keys = {sun:"sunny",moon:"clear",cloud:"cloudy",fog:"mist",rain:"rainy",snow:"snow",storm:"storm"};
        return I18n.t("weather.desc." + keys[condition]);
    }
    readonly property var hours: {
        let source = ready && Array.isArray(day.hourly) ? day.hourly : [];
        let start = root.weatherView===0 ? Math.max(0,root.activeHourIndex) : 3;
        start = Math.max(0, Math.min(start, source.length-4));
        return source.slice(start,start+4);
    }
    readonly property bool validTemperature: {
        let raw = root.weatherView===0 ? root.weatherData.current_temp : day.max;
        return ready && raw!==undefined && raw!==null && raw!=="" && Number.isFinite(Number(raw));
    }
    function temperature(raw) {
        return raw!==undefined && raw!==null && raw!=="" && Number.isFinite(Number(raw)) ? Math.round(Number(raw)) + "°" : "--";
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: card.root.s(22)
        spacing: card.root.s(6)
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: card.root.s(30)
            Layout.maximumHeight: card.root.s(30)
            IconButton {
                objectName: "weatherPreviousDay"
                Layout.preferredWidth: card.root.s(28)
                Layout.preferredHeight: card.root.s(28)
                buttonIcon: I18n.rtl ? "" : ""
                iconFontSize: card.root.s(11)
                accentColor: ThemeBackend.text
                bgOpacity: isHoveredOrHighlighted ? 0.10 : 0
                textColor: ThemeBackend.text
                enabled: card.root.targetWeatherView>0
                opacity: enabled?0.8:0.25
                onClicked: card.root.setWeatherView(card.root.targetWeatherView-1)
            }
            Text {
                Layout.fillWidth: true
                text: card.day.day_full ? card.day.day_full.toUpperCase() : I18n.t("calendar.loading")
                horizontalAlignment: Text.AlignHCenter
                color: ThemeBackend.subtext0
                font.family: ThemeBackend.fontFamily
                font.pixelSize: card.root.s(11)
                font.letterSpacing: card.root.s(1.6)
                elide: Text.ElideRight
            }
            IconButton {
                objectName: "weatherNextDay"
                Layout.preferredWidth: card.root.s(28)
                Layout.preferredHeight: card.root.s(28)
                buttonIcon: I18n.rtl ? "" : ""
                iconFontSize: card.root.s(11)
                accentColor: ThemeBackend.text
                bgOpacity: isHoveredOrHighlighted ? 0.10 : 0
                textColor: ThemeBackend.text
                enabled: card.root.targetWeatherView < Math.min(4,card.days.length-1)
                opacity: enabled?0.8:0.25
                onClicked: card.root.setWeatherView(card.root.targetWeatherView+1)
            }
        }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            opacity: card.root.weatherContentOpacity
            transform: Translate { x: card.root.weatherContentOffset * 0.35 }
            ColumnLayout {
                anchors.fill: parent
                spacing: card.root.s(4)
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: card.root.s(94)
                    Layout.minimumHeight: card.root.s(94)
                    Layout.maximumHeight: card.root.s(94)
                    Text {
                        objectName: "weatherLargeTemperature"
                        text: card.validTemperature ? Math.round(card.root.displayedTemp) + "°" : "--"
                        color: ThemeBackend.text
                        font.family: "sans-serif"
                        font.pixelSize: card.root.s(78)
                        font.weight: Font.Light
                        Layout.preferredWidth: card.root.s(174)
                    }
                    Text {
                        Layout.fillWidth: true
                        text: card.conditionText
                        color: ThemeBackend.text
                        font.family: "sans-serif"
                        font.pixelSize: card.root.s(22)
                        font.weight: Font.Normal
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                }
                AsciiWeatherArt {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: card.root.s(70)
                    condition: card.condition
                    active: card.root.visible
                    interacting: hover.hovered
                    ink: ThemeBackend.text
                    opacity: card.ready ? 1 : 0.25
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: card.root.s(68)
                    Layout.maximumHeight: card.root.s(68)
                    Layout.minimumHeight: card.root.s(68)
                    spacing: 0
                    Repeater {
                        model: card.hours
                        delegate: Item {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            HoverHandler { id: hourHover }
                            Rectangle {
                                anchors.left: parent.left
                                width: 1
                                height: parent.height-card.root.s(8)
                                anchors.verticalCenter: parent.verticalCenter
                                color: Qt.alpha(ThemeBackend.text,0.12)
                                visible: index>0
                            }
                            Column {
                                anchors.centerIn: parent
                                spacing: card.root.s(8)
                                transform: Translate {
                                    y: hourHover.hovered ? -card.root.s(2) : 0
                                    Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.time || "--"
                                    color: hourHover.hovered ? ThemeBackend.text : ThemeBackend.subtext0
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: card.root.s(16)
                                    Behavior on color { ColorAnimation { duration: 180 } }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: card.temperature(modelData.temp)
                                    color: ThemeBackend.text
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: card.root.s(22)
                                    font.weight: Font.Light
                                }
                            }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: card.hours.length===0
                        text: card.offline ? I18n.t("weather.desc.offline") : "Hourly forecast unavailable"
                        color: ThemeBackend.subtext0
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: card.root.s(12)
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: card.root.s(21)
            Layout.maximumHeight: card.root.s(21)
            Text {
                Layout.fillWidth: true
                text: (card.root.weatherData.city || "") + (card.ready ? ((card.root.weatherData.city ? " · " : "") + "H " + card.temperature(card.day.max) + "  L " + card.temperature(card.day.min)) : "")
                color: ThemeBackend.subtext0
                font.family: ThemeBackend.fontFamily
                font.pixelSize: card.root.s(10)
                elide: Text.ElideRight
            }
            Text {
                text: DateTime.time + "  ·  " + (Weather.unitSym || "°")
                color: ThemeBackend.subtext0
                font.family: ThemeBackend.fontFamily
                font.pixelSize: card.root.s(10)
            }
        }
    }
}
