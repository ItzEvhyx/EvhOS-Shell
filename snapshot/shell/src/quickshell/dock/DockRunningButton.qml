import QtQuick
import QtQuick.Layouts
import Quickshell // local checked icons
import "../"
import "../reusables"

Item {
    id: runningDockButton
    required property var dockWindow
    required property var dockContainer
    required property var model
    required property int index

    implicitWidth: dockWindow.s(dockWindow.dockElementSize)
    implicitHeight: dockWindow.s(dockWindow.dockElementSize)
    Layout.preferredWidth: dockWindow.s(dockWindow.dockElementSize)
    Layout.preferredHeight: dockWindow.s(dockWindow.dockElementSize)
    Layout.alignment: Qt.AlignCenter

    property int itemIndex: dockWindow.dockAppsModel.count + 1 + index
    property color btnColor: ThemeBackend.surface0
    property int cornerRadius: Math.round(dockWindow.s(dockWindow.dockElementSize) * 0.28)
    property int btnSize: dockWindow.s(dockWindow.dockElementSize)

    readonly property var runningInfo: dockWindow.getRunningInfoForApp(model.desktop_id)
    readonly property bool isAppRunning: runningInfo !== null && runningInfo.hasWindows
    readonly property bool isAppHere: runningInfo !== null && runningInfo.count > 0
    readonly property bool isAppFocused: runningInfo !== null && runningInfo.isFocused
    readonly property int appWindowCount: runningInfo !== null ? runningInfo.count : 0
    readonly property bool isOnlyElsewhere: runningInfo !== null && runningInfo.count === 0 && runningInfo.elsewhere.length > 0

    z: Math.round(runningBtnShape.scale * 100)

    readonly property bool canHoverScale: !dockWindow.editMode && dockWindow.dragSourceIndex === -1
    readonly property real maxHoverScale: dockWindow.dockHoverScaleMultiplier
    readonly property real hoverScaleDelta: Math.max(0.0, maxHoverScale - 1.0)

    property real baseHoverScale: {
        if (!canHoverScale || dockContainer.hoveredItemIndex < 0) return 1.0;
        let diff = Math.abs(runningDockButton.itemIndex - dockContainer.hoveredItemIndex);
        if (diff === 0) return maxHoverScale;
        if (dockWindow.dockCascadeScale) {
            if (diff === 1) return 1.0 + hoverScaleDelta * 0.45;
            if (diff === 2) return 1.0 + hoverScaleDelta * 0.15;
        }
        return 1.0;
    }

    property real targetScale: {
        let s = baseHoverScale;
        if (runningBtnMa.pressed && canHoverScale) {
            return s * 0.90;
        }
        return s;
    }

    property real animSpread: {
        if (!canHoverScale || dockContainer.hoveredItemIndex < 0) return 0.0;
        let diff = itemIndex - dockContainer.hoveredItemIndex;
        if (diff === 0) return 0.0;
        let sign = diff > 0 ? 1.0 : -1.0;
        let d = Math.abs(diff);
        let maxAllowedShift = Math.min(dockWindow.s(10), runningDockButton.btnSize * hoverScaleDelta * 0.65);
        if (dockWindow.dockCascadeScale) {
            let shift = (d === 1) ? (maxAllowedShift * 0.70) : maxAllowedShift;
            return sign * shift;
        } else {
            return (d === 1) ? (sign * maxAllowedShift * 0.45) : 0.0;
        }
    }

    property real animLift: {
        if (!canHoverScale || targetScale <= 1.0) return 0.0;
        let liftProgress = (targetScale - 1.0) / Math.max(0.01, maxHoverScale - 1.0);
        return dockWindow.s(5) * Math.min(1.0, Math.max(0.0, liftProgress));
    }

    property real targetOffsetX: {
        if (dockWindow.isVertical) {
            if (dockWindow.dockPosition === "left") return animLift;
            if (dockWindow.dockPosition === "right") return -animLift;
            return 0.0;
        }
        return animSpread;
    }

    property real targetOffsetY: {
        if (dockWindow.isVertical) return animSpread;
        if (dockWindow.dockPosition === "bottom") return -animLift;
        if (dockWindow.dockPosition === "top") return animLift;
        return 0.0;
    }

    property real currentOffsetX: targetOffsetX
    property real currentOffsetY: targetOffsetY

    Behavior on currentOffsetX {
        enabled: dockWindow.initialized && !dockWindow.positionChanging
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }
    Behavior on currentOffsetY {
        enabled: dockWindow.initialized && !dockWindow.positionChanging
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    Item {
        id: runningFloatWrapper
        anchors.fill: parent

        transform: Translate {
            x: runningDockButton.currentOffsetX
            y: runningDockButton.currentOffsetY
        }

        Rectangle {
            id: runningBtnShape
            anchors.fill: parent
            radius: runningDockButton.cornerRadius
            clip: true
            color: "transparent" // local icon-only dock

            GlassFill {
                id: runningBtnGlass
                visible: false // local icon-only dock
                anchors.fill: parent
                radius: parent.radius
                tintColor: runningDockButton.btnColor
                tintAmount: 0.3
                press: runningBtnMa.pressed ? 1 : Math.max(runningBtnMa.containsMouse ? 0.3 : 0, 0.3 * Math.max(0, Math.min(1, (runningDockButton.baseHoverScale - 1.0) / Math.max(0.01, runningDockButton.hoverScaleDelta))))
                Behavior on press { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            }
            transformOrigin: Item.Center
            scale: runningDockButton.targetScale

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on scale {
                NumberAnimation { duration: runningBtnMa.pressed ? 90 : 220; easing.type: Easing.OutCubic }
            }

            Image {
                id: runningAppIcon
                anchors.fill: parent
                anchors.margins: dockWindow.s(Math.round(dockWindow.dockElementSize * 0.14))
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                mipmap: true
                property bool failedLoad: false
                visible: source !== "" && status === Image.Ready && !failedLoad

                source: {
                    let ic = model.icon || "";
                    if (!ic) return "";
                    if (ic.startsWith("file://") || ic.startsWith("image://") || ic.startsWith("http://") || ic.startsWith("https://")) return ic;
                    return ic.startsWith("/") ? "file://" + ic : Quickshell.iconPath(ic, true); // local checked icons
                }
                onSourceChanged: failedLoad = false // local recycled icon reset
                onStatusChanged: failedLoad = status === Image.Error
            }

            Text {
                anchors.centerIn: parent
                visible: runningAppIcon.source === "" || runningAppIcon.failedLoad || runningAppIcon.status === Image.Error
                text: model.name ? model.name.charAt(0).toUpperCase() : "?"
                font.family: ThemeBackend.fontFamily
                font.pixelSize: dockWindow.s(Math.round(dockWindow.dockElementSize * 0.42))
                font.weight: Font.Bold
                color: ThemeBackend.text
            }


        }

        Item {
            id: runningIndicatorContainer
            visible: dockWindow.showRunningIndicators && runningDockButton.isAppRunning
            opacity: (visible && dockContainer.revealProgress > 0.1) ? 1.0 : 0.0

            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            z: 2

            // A short line marks every running app; the focused app is brighter.
            Rectangle {
                width: dockWindow.isVertical ? dockWindow.s(3) : dockWindow.s(runningDockButton.isAppFocused ? 18 : 12)
                height: dockWindow.isVertical ? dockWindow.s(runningDockButton.isAppFocused ? 18 : 12) : dockWindow.s(3)
                radius: dockWindow.s(2)
                anchors.horizontalCenter: dockWindow.isVertical ? undefined : parent.horizontalCenter
                anchors.verticalCenter: dockWindow.isVertical ? parent.verticalCenter : undefined
                anchors.bottom: !dockWindow.isVertical && dockWindow.dockPosition !== "top" ? parent.bottom : undefined
                anchors.top: !dockWindow.isVertical && dockWindow.dockPosition === "top" ? parent.top : undefined
                anchors.left: dockWindow.isVertical && dockWindow.dockPosition === "right" ? parent.left : undefined
                anchors.right: dockWindow.isVertical && dockWindow.dockPosition === "left" ? parent.right : undefined
                anchors.margins: dockWindow.s(1)
                color: Qt.alpha(ThemeBackend.text, runningDockButton.isOnlyElsewhere ? 0.4 : (runningDockButton.isAppFocused ? 1.0 : 0.7))
                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 160 } }
            }

        }

        MouseArea {
            id: runningBtnMa
            anchors.fill: parent
            anchors.margins: -Math.max(dockContainer.itemSpacing / 2, (runningBtnShape.scale - 1.0) * runningDockButton.btnSize / 2)
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor

            onEntered: {
                dockContainer.cancelHoverReset();
                if (runningDockButton.canHoverScale) {
                    dockContainer.hoveredItemIndex = runningDockButton.itemIndex;
                }
            }

            onExited: {
                if (dockContainer.hoveredItemIndex === runningDockButton.itemIndex) {
                    dockContainer.checkHoverReset();
                }
            }

            onClicked: function(mouse) {
                if (mouse.button === Qt.MiddleButton) {
                    dockWindow.launchApp(model.desktop_id);
                    return;
                }
                if (mouse.button === Qt.RightButton) {
                    let pt = runningDockButton.mapToItem(null, 0, 0);
                    let globX = pt.x + (runningDockButton.width / 2);
                    let globY = pt.y + (runningDockButton.height / 2);
                    let info = dockWindow.getRunningInfoForApp(model.desktop_id);
                    let winList = [];
                    if (info) {
                        if (info.here) winList = winList.concat(info.here);
                        if (info.elsewhere) winList = winList.concat(info.elsewhere);
                    }
                    DockAppMenuController.toggle(
                        dockWindow.screen,
                        globX,
                        globY,
                        dockWindow.dockPosition,
                        model.desktop_id,
                        model.name || (info ? info.appId : ""),
                        model.icon || "",
                        false,
                        winList,
                        runningDockButton.width
                    );
                    return;
                }
                if (mouse.button === Qt.LeftButton) {
                    if (typeof DockAppMenuController !== "undefined" && DockAppMenuController.isVisible && !DockAppMenuController.isSameApp(DockAppMenuController.desktopId, model.desktop_id)) {
                        let pt = runningDockButton.mapToItem(null, 0, 0);
                        let globX = pt.x + (runningDockButton.width / 2);
                        let globY = pt.y + (runningDockButton.height / 2);
                        let info = dockWindow.getRunningInfoForApp(model.desktop_id);
                        let winList = [];
                        if (info) {
                            if (info.here) winList = winList.concat(info.here);
                            if (info.elsewhere) winList = winList.concat(info.elsewhere);
                        }
                        DockAppMenuController.show(
                            dockWindow.screen,
                            globX,
                            globY,
                            dockWindow.dockPosition,
                            model.desktop_id,
                            model.name || (info ? info.appId : ""),
                            model.icon || "",
                            false,
                            winList,
                            runningDockButton.width
                        );
                        return;
                    }

                    if (typeof DockAppMenuController !== "undefined" && DockAppMenuController.isVisible && DockAppMenuController.isSameApp(DockAppMenuController.desktopId, model.desktop_id)) {
                        DockAppMenuController.hide();
                    }

                    if (typeof Sounds !== "undefined") Sounds.playSfx("reusables/iconbutton/click.wav");
                    dockWindow.activateOrLaunch(model.desktop_id, mouse.modifiers);
                }
            }
        }
    }
}
