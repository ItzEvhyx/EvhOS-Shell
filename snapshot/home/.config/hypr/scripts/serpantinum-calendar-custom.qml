import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtCore
import Quickshell
import Quickshell.Io
import QtQuick.Window
import "../"
import "../reusables"

Item {
    id: window
    visible: false
    focus: true

    function s(val) {
        return Scaler.s(val);
    }

    property real targetMasterHeight: window.s(510)
    property real targetMasterWidth: window.s(1360)
    implicitWidth: targetMasterWidth
    implicitHeight: targetMasterHeight
    width: targetMasterWidth
    height: targetMasterHeight

    Timer {
        id: focusTimer
        interval: 50
        repeat: false
        onTriggered: window.forceActiveFocus()
    }

    Shortcut {
        sequence: "Left"
        enabled: window.visible && !window.editingEvent
        onActivated: {
            if (calHover.hovered) {
                window.setMonthOffset(window.targetMonthOffset - 1);
            } else {
                window.setWeatherView(window.targetWeatherView - 1);
            }
        }
    }

    Shortcut {
        sequence: "Right"
        enabled: window.visible && !window.editingEvent
        onActivated: {
            if (calHover.hovered) {
                window.setMonthOffset(window.targetMonthOffset + 1);
            } else {
                window.setWeatherView(window.targetWeatherView + 1);
            }
        }
    }

    readonly property color base: ThemeBackend.base
    readonly property color mantle: ThemeBackend.mantle
    readonly property color crust: ThemeBackend.crust
    readonly property color text: ThemeBackend.text
    readonly property color subtext1: ThemeBackend.subtext1
    readonly property color subtext0: ThemeBackend.subtext0
    readonly property color overlay2: ThemeBackend.overlay2
    readonly property color overlay1: ThemeBackend.overlay1
    readonly property color overlay0: ThemeBackend.overlay0
    readonly property color surface2: ThemeBackend.surface2
    readonly property color surface1: ThemeBackend.surface1
    readonly property color surface0: ThemeBackend.surface0

    readonly property color mauve: ThemeBackend.mauve
    readonly property color pink: ThemeBackend.pink
    readonly property color blue: ThemeBackend.blue
    readonly property color sapphire: ThemeBackend.sapphire
    readonly property color peach: ThemeBackend.peach
    readonly property color yellow: ThemeBackend.yellow
    readonly property color teal: ThemeBackend.teal
    readonly property color green: ThemeBackend.green
    readonly property color red: ThemeBackend.red

    readonly property string scriptsDir: Caching.qsDir + "/calendar"

    readonly property color timeColor: {
        let h = window.currentTime.getHours();
        if (h >= 5 && h < 12) return window.peach;
        if (h >= 12 && h < 17) return window.sapphire;
        if (h >= 17 && h < 21) return window.mauve;
        return window.blue;
    }

    readonly property color timeAccent: {
        let h = window.currentTime.getHours();
        if (h >= 5 && h < 12) return window.yellow;
        if (h >= 12 && h < 17) return window.teal;
        if (h >= 17 && h < 21) return window.pink;
        return window.mauve;
    }

    readonly property color textAccent: Qt.tint(window.timeAccent, Qt.alpha(window.text, 0.35))

    property bool startupComplete: false
    property real introMain: 0
    property real introAmbient: 0
    property real introClock: 0
    property real introCalendar: 0
    property real introWeather: 0

    property var exitCallback: null

    function startExit(onFinished) {
        introAnim.stop();
        exitCallback = onFinished;
        exitAnim.restart();
    }

    function resetAndPlayIntro() {
        exitAnim.stop();
        startupComplete = false;
        introMain = 0;
        introAmbient = 0;
        introClock = 0;
        introCalendar = 0;
        introWeather = 0;
        transitionSpin = 0.0;
        transitionScale = 1.0;
        weatherContentOpacity = 1.0;
        weatherContentOffset = 0.0;
        calendarContentOpacity = 1.0;
        calendarContentOffset = 0.0;
        introAnim.restart();
    }

    onVisibleChanged: {
        if (visible) {
            forceActiveFocus();
            focusTimer.restart();
            window.gridDay = DateTime.now.getDate();
            updateCalendarGrid();
            Weather.refresh(false);
            resetAndPlayIntro();
        } else {
            editingEvent = false;
            introAnim.stop();
            exitAnim.stop();
            weatherTransitionAnim.stop();
            calendarTransitionAnim.stop();
            startupComplete = false;
            introMain = 0;
            introAmbient = 0;
            introClock = 0;
            introCalendar = 0;
            introWeather = 0;
            transitionSpin = 0.0;
            transitionScale = 1.0;
            weatherContentOpacity = 1.0;
            weatherContentOffset = 0.0;
            calendarContentOpacity = 1.0;
            calendarContentOffset = 0.0;
        }
    }

    SequentialAnimation {
        id: introAnim
        running: false

        PauseAnimation { duration: 7 }

        ParallelAnimation {
            NumberAnimation { target: window; property: "introMain"; from: 0; to: 1.0; duration: 272; easing.type: Easing.OutQuart }

            SequentialAnimation {
                PauseAnimation { duration: 51 }
                NumberAnimation { target: window; property: "introAmbient"; from: 0; to: 1.0; duration: 340; easing.type: Easing.OutSine }
            }

            SequentialAnimation {
                PauseAnimation { duration: 85 }
                NumberAnimation { target: window; property: "introClock"; from: 0; to: 1.0; duration: 306; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
            }

            SequentialAnimation {
                PauseAnimation { duration: 136 }
                NumberAnimation { target: window; property: "introCalendar"; from: 0; to: 1.0; duration: 289; easing.type: Easing.OutQuint }
            }

            SequentialAnimation {
                PauseAnimation { duration: 136 }
                NumberAnimation { target: window; property: "introWeather"; from: 0; to: 1.0; duration: 289; easing.type: Easing.OutQuint }
            }
        }
        ScriptAction { script: window.startupComplete = true }
    }

    SequentialAnimation {
        id: exitAnim
        running: false
        ParallelAnimation {
            NumberAnimation { target: window; property: "introWeather"; to: 0; duration: 150; easing.type: Easing.InCubic }
            NumberAnimation { target: window; property: "introCalendar"; to: 0; duration: 150; easing.type: Easing.InCubic }
            SequentialAnimation {
                PauseAnimation { duration: 30 }
                NumberAnimation { target: window; property: "introClock"; to: 0; duration: 160; easing.type: Easing.InBack }
                NumberAnimation { target: window; property: "introAmbient"; to: 0; duration: 150; easing.type: Easing.InQuad }
            }
            SequentialAnimation {
                PauseAnimation { duration: 50 }
                NumberAnimation { target: window; property: "introMain"; to: 0; duration: 150; easing.type: Easing.InQuart }
            }
        }
        ScriptAction {
            script: {
                if (window.exitCallback) {
                    let cb = window.exitCallback;
                    window.exitCallback = null;
                    cb();
                }
            }
        }
    }

    property var currentTime: DateTime.now
    property real currentEpoch: currentTime.getTime() / 1000

    property real secondPulse: 1.0
    NumberAnimation on secondPulse {
        id: pulseReset
        to: 1.0; duration: 600; easing.type: Easing.OutQuint; running: false
    }

    property int gridDay: -1

    Connections {
        target: DateTime
        enabled: window.visible
        function onNowChanged() {
            window.secondPulse = 1.02;
            pulseReset.start();

            let day = DateTime.now.getDate();
            if (day !== window.gridDay) {
                window.gridDay = day;
                window.updateCalendarGrid();
            }
        }
    }

    property var weatherData: Weather.data
    property int weatherView: 0
    property color activeWeatherHex: {
        if (!window.weatherData) return window.mauve;
        if (window.weatherView === 0 && window.weatherData.current_hex) return window.weatherData.current_hex;
        if (window.weatherData.forecast && window.weatherData.forecast[window.weatherView] && window.weatherData.forecast[window.weatherView].hex) return window.weatherData.forecast[window.weatherView].hex;
        return window.mauve;
    }

    property int targetWeatherView: 0
    property real weatherContentOpacity: 1.0
    property real weatherContentOffset: 0.0
    property int weatherAnimDirection: 1

    property real transitionSpin: 0.0
    property real transitionScale: 1.0

    property real targetTemp: {
        if (!window.weatherData || window.weatherData.offline) return 0;
        if (window.targetWeatherView === 0 && window.weatherData.current_temp !== undefined) {
            return Number(window.weatherData.current_temp);
        }
        if (window.weatherData.forecast && window.weatherData.forecast[window.targetWeatherView]) {
            return Number(window.weatherData.forecast[window.targetWeatherView].max);
        }
        return 0;
    }

    property real displayedTemp: targetTemp

    Behavior on displayedTemp {
        NumberAnimation {
            id: tempAnim
            duration: 800
            easing.type: Easing.OutQuart
        }
    }

    property bool isTempAnimating: tempAnim.running
    property color tempGlowColor: {
        if (!isTempAnimating || !window.startupComplete) return window.text;
        if (window.targetTemp > window.displayedTemp) return window.red;
        if (window.targetTemp < window.displayedTemp) return window.blue;
        return window.text;
    }

    SequentialAnimation {
        id: weatherTransitionAnim
        ParallelAnimation {
            NumberAnimation { target: window; property: "weatherContentOpacity"; to: 0.0; duration: 250; easing.type: Easing.InSine }
            NumberAnimation { target: window; property: "weatherContentOffset"; to: -window.s(40) * weatherAnimDirection; duration: 250; easing.type: Easing.InSine }
            NumberAnimation { target: window; property: "transitionSpin"; to: 180 * weatherAnimDirection; duration: 250; easing.type: Easing.InBack }
            NumberAnimation { target: window; property: "transitionScale"; to: 0.8; duration: 250; easing.type: Easing.InCubic }
        }
        ScriptAction {
            script: {
                window.weatherView = window.targetWeatherView;
                window.weatherContentOffset = window.s(40) * weatherAnimDirection;
                window.transitionSpin = -180 * weatherAnimDirection;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: window; property: "weatherContentOpacity"; to: 1.0; duration: 400; easing.type: Easing.OutQuart }
            NumberAnimation { target: window; property: "weatherContentOffset"; to: 0.0; duration: 400; easing.type: Easing.OutQuart }
            NumberAnimation { target: window; property: "transitionSpin"; to: 0.0; duration: 600; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            NumberAnimation { target: window; property: "transitionScale"; to: 1.0; duration: 500; easing.type: Easing.OutBack }
        }
    }

    function setWeatherView(idx) {
        if (!window.weatherData || !window.weatherData.forecast || idx < 0 || idx > Math.min(4, window.weatherData.forecast.length - 1)) return;
        if (idx === window.targetWeatherView) return;

        if (weatherTransitionAnim.running) {
            weatherTransitionAnim.stop();
            window.weatherView = window.targetWeatherView;
            window.transitionSpin = 0.0;
            window.transitionScale = 1.0;
            window.weatherContentOpacity = 1.0;
            window.weatherContentOffset = 0.0;
        }

        window.weatherAnimDirection = idx > window.weatherView ? 1 : -1;
        window.targetWeatherView = idx;
        weatherTransitionAnim.start();
    }

    property int activeHourIndex: {
        if (window.weatherView !== 0 || !window.weatherData || !window.weatherData.forecast || !window.weatherData.forecast[0] || !window.weatherData.forecast[0].hourly) return -1;

        let ch = window.currentTime.getHours();
        let hrArr = window.weatherData.forecast[0].hourly.slice(0, 8);
        let bestIdx = -1;
        let minDiff = 999;

        for (let i = 0; i < hrArr.length; i++) {
            let timeStr = hrArr[i].time || "00:00";
            let parts = timeStr.trim().split(" ");
            let clockPart = parts.length > 1 && parts[0].includes("-") ? parts[1] : parts[0];
            let h = parseInt(clockPart.split(":")[0]);
            if (isNaN(h)) h = 0;
            let diff = Math.abs(h - ch);
            if (diff < minDiff) {
                minDiff = diff;
                bestIdx = i;
            }
        }
        return bestIdx !== -1 ? bestIdx : 0;
    }

    property real centerOffset: window.s(20)
    property int monthOffset: 0
    property int targetMonthOffset: 0
    property string targetMonthName: ""
    ListModel { id: calendarModel }
    property var calendarEvents: ({})
    property string selectedDate: ""
    property bool editingEvent: false

    component EventButton: Button {
        id: control
        property bool primary: false
        property bool destructive: false
        implicitWidth: Math.max(window.s(68), label.implicitWidth + window.s(26))
        implicitHeight: window.s(32)
        hoverEnabled: true
        padding: 0
        contentItem: Text {
            id: label
            text: control.text
            font.family: ThemeBackend.fontFamily
            font.pixelSize: window.s(11)
            font.weight: control.primary ? Font.DemiBold : Font.Medium
            color: !control.enabled ? Qt.alpha(window.text, 0.35)
                   : control.primary ? window.base
                   : control.destructive ? window.red : window.text
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: window.s(10)
            color: !control.enabled ? Qt.alpha(window.text, 0.05)
                   : control.primary ? (control.down ? Qt.alpha(window.text, 0.72)
                                         : control.hovered ? Qt.alpha(window.text, 0.9) : window.text)
                   : control.destructive ? Qt.alpha(window.red, control.down ? 0.24 : control.hovered ? 0.16 : 0.09)
                   : Qt.alpha(window.text, control.down ? 0.18 : control.hovered ? 0.14 : 0.08)
            border.width: control.visualFocus ? 1 : 0
            border.color: Qt.alpha(window.text, 0.65)
            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }

    FileView {
        id: eventFile
        path: Quickshell.env("HOME") + "/.config/serpantinum/calendar-events.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { window.calendarEvents = JSON.parse(text()); }
            catch (e) { console.warn("Could not read calendar events:", e); }
            window.updateCalendarGrid();
        }
    }

    function dateKey(date) {
        return date.getFullYear() + "-" + ("0" + (date.getMonth() + 1)).slice(-2) + "-" + ("0" + date.getDate()).slice(-2);
    }
    function openEvent(key) {
        selectedDate = key;
        let event = calendarEvents[key] || {};
        eventName.text = event.name || "";
        eventDetails.text = event.details || "";
        editingEvent = true;
        eventName.forceActiveFocus();
    }
    function saveEvent() {
        let name = eventName.text.trim();
        if (!name) { eventName.forceActiveFocus(); return; }
        let events = Object.assign({}, calendarEvents);
        events[selectedDate] = { name: name, details: eventDetails.text.trim() };
        calendarEvents = events;
        eventFile.setText(JSON.stringify(events, null, 2));
        editingEvent = false;
        updateCalendarGrid();
    }
    function deleteEvent() {
        let events = Object.assign({}, calendarEvents);
        delete events[selectedDate];
        calendarEvents = events;
        eventFile.setText(JSON.stringify(events, null, 2));
        editingEvent = false;
        updateCalendarGrid();
    }

    property real calendarContentOpacity: 1.0
    property real calendarContentOffset: 0.0
    property int calendarAnimDirection: 1

    SequentialAnimation {
        id: calendarTransitionAnim
        ParallelAnimation {
            NumberAnimation { target: window; property: "calendarContentOpacity"; to: 0.0; duration: 250; easing.type: Easing.InSine }
            NumberAnimation { target: window; property: "calendarContentOffset"; to: -window.s(20) * calendarAnimDirection; duration: 250; easing.type: Easing.InSine }
        }
        ScriptAction {
            script: {
                window.monthOffset = window.targetMonthOffset;
                window.calendarContentOffset = window.s(20) * calendarAnimDirection;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: window; property: "calendarContentOpacity"; to: 1.0; duration: 400; easing.type: Easing.OutQuart }
            NumberAnimation { target: window; property: "calendarContentOffset"; to: 0.0; duration: 400; easing.type: Easing.OutQuart }
        }
    }

    function setMonthOffset(newOffset) {
        if (newOffset === window.targetMonthOffset) return;

        if (calendarTransitionAnim.running) {
            calendarTransitionAnim.stop();
            window.monthOffset = window.targetMonthOffset;
            window.calendarContentOpacity = 1.0;
            window.calendarContentOffset = 0.0;
        }

        window.calendarAnimDirection = newOffset > window.targetMonthOffset ? 1 : -1;
        window.targetMonthOffset = newOffset;
        calendarTransitionAnim.start();
    }

    function updateCalendarGrid() {
        let d = new Date(window.currentTime.getTime());
        d.setDate(1);
        d.setMonth(d.getMonth() + window.monthOffset);

        let targetMonth = d.getMonth();
        let targetYear = d.getFullYear();

        let actualToday = new Date();
        let isRealCurrentMonth = (actualToday.getMonth() === targetMonth && actualToday.getFullYear() === targetYear);
        let todayDate = actualToday.getDate();

        let monthLoc = Qt.locale(I18n.qtLocaleName);
        // standalone month name, so Ukrainian reads "Жовтень 2026" and not "жовтня 2026"
        let monthName = monthLoc.standaloneMonthName(d.getMonth(), Locale.LongFormat);
        window.targetMonthName = monthName.charAt(0).toUpperCase() + monthName.slice(1) + " " + d.getFullYear();

        let firstDay = new Date(targetYear, targetMonth, 1).getDay();
        firstDay = (firstDay === 0) ? 6 : firstDay - 1;

        calendarModel.clear();
        for (let i = 0; i < 42; i++) {
            let cellDate = new Date(targetYear, targetMonth, 1 - firstDay + i);
            let key = dateKey(cellDate);
            calendarModel.append({
                dayNum: cellDate.getDate().toString(),
                dateKey: key,
                hasEvent: !!calendarEvents[key],
                isCurrentMonth: cellDate.getMonth() === targetMonth,
                isToday: key === dateKey(actualToday)
            });
        }
    }

    onMonthOffsetChanged: updateCalendarGrid()

    Component.onCompleted: {
        updateCalendarGrid();
        if (visible) {
            forceActiveFocus();
            focusTimer.restart();
            Weather.refresh(false);
            resetAndPlayIntro();
        }
    }

    Item {
        anchors.fill: parent
        scale: 0.95 + (0.05 * introMain)
        opacity: introMain

        Rectangle {
            anchors.fill: parent
            radius: ThemeBackend.borderRadius
            color: Qt.alpha(ThemeBackend.base, 0.78) // local translucent widget
            clip: true

            WallpaperBlur {
                z: -1
                anchors.fill: parent
                topLeftRadius: parent.topLeftRadius
                topRightRadius: parent.topRightRadius
                bottomLeftRadius: parent.bottomLeftRadius
                bottomRightRadius: parent.bottomRightRadius
            }

            Rectangle {
                width: parent.width * 0.5; height: width; radius: width / 2
                x: parent.width * 0.75 - width / 2
                y: parent.height * 0.3 - height / 2
                opacity: 0.012 * window.introAmbient
                color: window.activeWeatherHex
                Behavior on color { ColorAnimation { duration: 1000 } }

                transform: Translate {
                    SequentialAnimation on x {
                        loops: Animation.Infinite
                        running: window.visible
                        NumberAnimation { from: window.s(350); to: -window.s(350); duration: 30000; easing.type: Easing.InOutSine }
                        NumberAnimation { from: -window.s(350); to: window.s(350); duration: 30000; easing.type: Easing.InOutSine }
                    }
                    SequentialAnimation on y {
                        loops: Animation.Infinite
                        running: window.visible
                        NumberAnimation { from: 0; to: window.s(200); duration: 15000; easing.type: Easing.OutSine }
                        NumberAnimation { from: window.s(200); to: -window.s(200); duration: 30000; easing.type: Easing.InOutSine }
                        NumberAnimation { from: -window.s(200); to: 0; duration: 15000; easing.type: Easing.InSine }
                    }
                }
            }

            Rectangle {
                width: parent.width * 0.6; height: width; radius: width / 2
                x: parent.width * 0.25 - width / 2
                y: parent.height * 0.7 - height / 2
                opacity: 0.01 * window.introAmbient
                color: window.timeColor
                Behavior on color { ColorAnimation { duration: 1000 } }

                transform: Translate {
                    SequentialAnimation on x {
                        loops: Animation.Infinite
                        running: window.visible
                        NumberAnimation { from: 0; to: -window.s(300); duration: 18750; easing.type: Easing.OutSine }
                        NumberAnimation { from: -window.s(300); to: window.s(300); duration: 37500; easing.type: Easing.InOutSine }
                        NumberAnimation { from: window.s(300); to: 0; duration: 18750; easing.type: Easing.InSine }
                    }
                    SequentialAnimation on y {
                        loops: Animation.Infinite
                        running: window.visible
                        NumberAnimation { from: -window.s(250); to: window.s(250); duration: 37500; easing.type: Easing.InOutSine }
                        NumberAnimation { from: window.s(250); to: -window.s(250); duration: 37500; easing.type: Easing.InOutSine }
                    }
                }
            }

            Rectangle {
                width: parent.width * 0.45; height: width; radius: width / 2
                x: parent.width * 0.5 - width / 2
                y: parent.height * 0.5 - height / 2
                opacity: 0.007 * window.introAmbient
                color: window.timeAccent
                Behavior on color { ColorAnimation { duration: 1000 } }

                transform: Translate {
                    SequentialAnimation on x {
                        loops: Animation.Infinite
                        running: window.visible
                        NumberAnimation { from: window.s(400); to: -window.s(400); duration: 25000; easing.type: Easing.InOutSine }
                        NumberAnimation { from: -window.s(400); to: window.s(400); duration: 25000; easing.type: Easing.InOutSine }
                    }
                    SequentialAnimation on y {
                        loops: Animation.Infinite
                        running: window.visible
                        NumberAnimation { from: 0; to: -window.s(350); duration: 12500; easing.type: Easing.OutSine }
                        NumberAnimation { from: -window.s(350); to: window.s(350); duration: 25000; easing.type: Easing.InOutSine }
                        NumberAnimation { from: window.s(350); to: 0; duration: 12500; easing.type: Easing.InSine }
                    }
                }
            }

            AsciiWeatherCard {
                root: window
                anchors.left: calendarRect.right
                anchors.leftMargin: window.s(26)
                anchors.right: usageDashboard.left
                anchors.rightMargin: window.s(26)
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.topMargin: window.s(26)
                anchors.bottomMargin: window.s(26)
                z: 5
                opacity: window.introWeather
            }

            Rectangle {
                id: calendarRect
                objectName: "calendarMonthPanel"
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: window.s(40)
                width: window.s(310)
                height: parent.height - window.s(52)
                radius: window.s(20)
                color: calendarGlass.active ? "transparent" : Qt.alpha(window.text, 0.055)
                border.width: 1
                border.color: Qt.alpha(window.text, 0.11)
                z: 10
                HoverHandler { id: calHover }

                GlassFill {
                    id: calendarGlass
                    anchors.fill: parent
                    radius: parent.radius
                    tintColor: window.surface0
                    tintAmount: 0.25
                }

                opacity: introCalendar
                transform: Translate { x: -window.s(40) * (1.0 - introCalendar) }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: window.s(18)
                    spacing: window.s(10)
                    visible: !window.editingEvent

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: window.s(32)
                        spacing: window.s(4)
                        layoutDirection: I18n.layoutDirection

                        Text {
                            Layout.fillWidth: true
                            text: window.targetMonthName
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.DemiBold
                            font.pixelSize: window.s(14)
                            fontSizeMode: Text.Fit
                            minimumPixelSize: window.s(8)
                            color: window.text
                            elide: Text.ElideRight
                            opacity: window.calendarContentOpacity
                            transform: Translate { x: window.calendarContentOffset }
                        }

                        IconButton {
                            visible: window.targetMonthOffset !== 0
                            size: window.s(28)
                            cornerRadius: window.s(10)
                            buttonIcon: "󰃭"
                            iconFontSize: window.s(14)
                            accentColor: window.text
                            bgOpacity: isHoveredOrHighlighted ? 0.14 : 0.06
                            textColor: window.text
                            onClicked: window.setMonthOffset(0)
                        }
                        IconButton {
                            size: window.s(28)
                            cornerRadius: window.s(10)
                            buttonIcon: I18n.rtl ? "" : ""
                            iconFontSize: window.s(14)
                            accentColor: window.text
                            bgOpacity: isHoveredOrHighlighted ? 0.14 : 0.06
                            textColor: window.text
                            onClicked: window.setMonthOffset(window.targetMonthOffset - 1)
                        }
                        IconButton {
                            size: window.s(28)
                            cornerRadius: window.s(10)
                            buttonIcon: I18n.rtl ? "" : ""
                            iconFontSize: window.s(14)
                            accentColor: window.text
                            bgOpacity: isHoveredOrHighlighted ? 0.14 : 0.06
                            textColor: window.text
                            onClicked: window.setMonthOffset(window.targetMonthOffset + 1)
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Qt.alpha(window.text, 0.09)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: window.s(20)
                        spacing: window.s(3)
                        layoutDirection: I18n.layoutDirection
                        Repeater {
                            model: [I18n.t("calendar.days.mo"), I18n.t("calendar.days.tu"), I18n.t("calendar.days.we"), I18n.t("calendar.days.th"), I18n.t("calendar.days.fr"), I18n.t("calendar.days.sa"), I18n.t("calendar.days.su")]
                            Text {
                                Layout.fillWidth: true
                                text: modelData
                                font.family: ThemeBackend.fontFamily
                                font.weight: Font.Medium
                                font.pixelSize: window.s(10)
                                color: window.subtext0
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 7
                        rowSpacing: window.s(2)
                        columnSpacing: window.s(3)
                        layoutDirection: I18n.layoutDirection
                        opacity: window.calendarContentOpacity
                        transform: Translate { x: window.calendarContentOffset }

                        Repeater {
                            model: calendarModel
                            Item {
                                required property string dayNum
                                required property bool isCurrentMonth
                                required property bool isToday
                                required property string dateKey
                                required property bool hasEvent
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: Math.min(parent.width, window.s(34))
                                    height: width
                                    radius: width / 2
                                    color: isToday ? window.textAccent : "transparent"
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: dayNum
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: window.s(11)
                                    font.weight: isToday ? Font.Bold : Font.Medium
                                    color: isToday ? window.base : (isCurrentMonth ? window.text : window.subtext0)
                                    opacity: isCurrentMonth ? 1 : 0.42
                                }
                                Rectangle {
                                    width: window.s(4); height: width; radius: width / 2
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: window.s(1)
                                    color: window.textAccent
                                    visible: hasEvent
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: window.openEvent(dateKey)
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: window.s(18)
                    spacing: window.s(9)
                    visible: window.editingEvent
                    Text {
                        Layout.fillWidth: true
                        text: window.selectedDate
                        color: window.text
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: window.s(14)
                        font.bold: true
                    }
                    Text {
                        text: "Event name"
                        color: window.subtext0
                        font.pixelSize: window.s(11)
                    }
                    TextField {
                        id: eventName
                        Layout.fillWidth: true
                        placeholderText: "Add a name"
                        color: window.text
                        placeholderTextColor: window.subtext0
                        font.pixelSize: window.s(12)
                        background: Rectangle { radius: window.s(8); color: Qt.alpha(window.text, 0.08) }
                    }
                    Text {
                        text: "Details"
                        color: window.subtext0
                        font.pixelSize: window.s(11)
                    }
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        TextArea {
                            id: eventDetails
                            placeholderText: "Add details (optional)"
                            color: window.text
                            placeholderTextColor: window.subtext0
                            font.pixelSize: window.s(12)
                            wrapMode: TextEdit.Wrap
                            background: Rectangle { radius: window.s(8); color: Qt.alpha(window.text, 0.08) }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: window.s(6)
                        EventButton { text: "Back"; onClicked: window.editingEvent = false }
                        EventButton { text: "Delete"; destructive: true; visible: !!window.calendarEvents[window.selectedDate]; onClicked: window.deleteEvent() }
                        Item { Layout.fillWidth: true }
                        EventButton { text: "Save"; primary: true; enabled: eventName.text.trim().length > 0; onClicked: window.saveEvent() }
                    }
                }
            }

            CodexUsageDashboard {
                id: usageDashboard
                anchors.right: parent.right; anchors.rightMargin: window.s(32)
                anchors.verticalCenter: parent.verticalCenter
                width: window.s(320); height: window.s(490)
                active: window.visible
                opacity: window.introWeather
            }
        }
    }
}
