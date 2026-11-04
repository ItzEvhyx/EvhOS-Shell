import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Rectangle {
    id: root
    width: Screen.width; height: Screen.height; color: "#080808"
    readonly property real scaleUnit: Math.min(width / 1920, height / 1080)
    property date currentTime: new Date()
    property int userIndex: typeof userModel !== "undefined" && userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property string errorText: ""
    readonly property string userName: userHelper.currentItem ? userHelper.currentItem.loginName : (typeof userModel !== "undefined" ? userModel.lastUser : "")
    readonly property string displayName: userHelper.currentItem ? userHelper.currentItem.displayName : "User"
    function authenticate() { if (userName && password.text && typeof sddm !== "undefined") { errorText = ""; sddm.login(userName, password.text, sessionIndex); } }
    Timer { interval: 1000; repeat: true; running: true; onTriggered: root.currentTime = new Date() }
    Timer { interval: 300; running: true; onTriggered: password.forceActiveFocus() }
    Connections { target: typeof sddm !== "undefined" ? sddm : null
        function onLoginFailed() { root.errorText = "Incorrect password. Try again."; password.clear(); password.forceActiveFocus(); }
    }
    ListView {
        id: userHelper; width: 1; height: 1; opacity: 0; z: -1
        model: typeof userModel !== "undefined" ? userModel : null; currentIndex: root.userIndex
        delegate: Item { property string loginName: model.name || ""; property string displayName: model.realName || model.name || "User" }
    }
    Image { anchors.fill: parent; source: "wallpaper.png"; fillMode: Image.PreserveAspectCrop; smooth: true }
    Rectangle { anchors.fill: parent; color: "#08000000" }
    Column {
        anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top
        anchors.topMargin: 115 * root.scaleUnit; spacing: 12 * root.scaleUnit
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDate(root.currentTime, "dddd").toUpperCase(); font.family: "Noto Sans"; font.bold: true; font.pixelSize: 35 * root.scaleUnit; font.letterSpacing: 12 * root.scaleUnit; color: "#161c1c" }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDate(root.currentTime, "dd MMMM yyyy").toUpperCase(); font.family: "Noto Sans"; font.bold: true; font.pixelSize: 14 * root.scaleUnit; font.letterSpacing: 5 * root.scaleUnit; color: "#202626" }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatTime(root.currentTime, "HH:mm"); font.family: "Noto Sans"; font.bold: true; font.pixelSize: 16 * root.scaleUnit; font.letterSpacing: 4 * root.scaleUnit; color: "#202626" }
    }
    Rectangle {
        id: card; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom
        anchors.bottomMargin: 175 * root.scaleUnit
        width: 600 * root.scaleUnit; height: 90 * root.scaleUnit
        radius: 14 * root.scaleUnit; color: "#e51b1b1c"; border.color: "#403e3e40"; border.width: 1
        Rectangle { id: portraitMask; x: 18 * root.scaleUnit; y: 18 * root.scaleUnit; width: 54 * root.scaleUnit; height: width; radius: width / 2; visible: false; layer.enabled: true }
        Image { id: portrait; anchors.fill: portraitMask; source: "profile.jpg"; fillMode: Image.PreserveAspectCrop; visible: false }
        OpacityMask { anchors.fill: portraitMask; source: portrait; maskSource: portraitMask }
        Text { id: account; anchors.left: portraitMask.right; anchors.leftMargin: 14 * root.scaleUnit; anchors.verticalCenter: parent.verticalCenter
            width: 145 * root.scaleUnit; text: root.displayName; color: "white"; elide: Text.ElideRight
            font.family: "Noto Sans"; font.bold: true; font.pixelSize: 16 * root.scaleUnit; font.letterSpacing: 1 * root.scaleUnit
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: typeof userModel !== "undefined" && userModel.rowCount() > 1; onClicked: { root.userIndex = (root.userIndex + 1) % userModel.rowCount(); password.clear(); password.forceActiveFocus(); } }
        }
        Rectangle {
            anchors.left: account.right; anchors.right: parent.right; anchors.rightMargin: 14 * root.scaleUnit; anchors.verticalCenter: parent.verticalCenter
            height: 56 * root.scaleUnit; radius: 10 * root.scaleUnit; color: "#b21c2020"; border.color: "#5b777777"; border.width: 1
            TextInput { id: password; anchors.fill: parent; anchors.leftMargin: 18 * root.scaleUnit; anchors.rightMargin: 56 * root.scaleUnit
                color: "white"; verticalAlignment: TextInput.AlignVCenter; font.family: "Noto Sans"; font.pixelSize: 20 * root.scaleUnit
                echoMode: TextInput.Password; inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText; selectByMouse: true; onAccepted: root.authenticate()
                Text { anchors.verticalCenter: parent.verticalCenter; visible: !password.text; text: "Password"; font: password.font; color: "#bfc4c4" }
            }
            Text { anchors.right: parent.right; anchors.rightMargin: 16 * root.scaleUnit; anchors.verticalCenter: parent.verticalCenter; text: "→"; color: "white"; font.pixelSize: 26 * root.scaleUnit
                MouseArea { anchors.fill: parent; anchors.margins: -10 * root.scaleUnit; cursorShape: Qt.PointingHandCursor; onClicked: root.authenticate() } }
        }
        Text { anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.bottom; anchors.topMargin: 8 * root.scaleUnit; text: root.errorText; color: "#ffd0d0"; font.bold: true; font.pixelSize: 14 * root.scaleUnit }

    }
    Row {
        anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.rightMargin: 55 * root.scaleUnit; anchors.bottomMargin: 52 * root.scaleUnit; spacing: 18 * root.scaleUnit
        ComboBox {
            id: sessions; width: 245 * root.scaleUnit; height: 45 * root.scaleUnit; model: typeof sessionModel !== "undefined" ? sessionModel : null
            textRole: "name"; currentIndex: root.sessionIndex; onActivated: index => { root.sessionIndex = index; password.forceActiveFocus(); }
            background: Rectangle { color: sessions.hovered ? "#a42b2b2c" : "#820b0b0c"; radius: 10 * root.scaleUnit }
            contentItem: Text { leftPadding: 14 * root.scaleUnit; rightPadding: 26 * root.scaleUnit; verticalAlignment: Text.AlignVCenter; text: sessions.displayText || "Select session"; elide: Text.ElideRight; color: "white"; font.family: "Noto Sans"; font.bold: true; font.pixelSize: 14 * root.scaleUnit }
            indicator: Text { x: sessions.width - width - 12 * root.scaleUnit; anchors.verticalCenter: parent.verticalCenter; text: "⌄"; color: "white"; font.pixelSize: 20 * root.scaleUnit }
            delegate: ItemDelegate { required property int index; required property var model; width: sessions.width; text: model.name; highlighted: sessions.highlightedIndex === index }
        }
        Button {
            id: powerButton; width: 53 * root.scaleUnit; height: 45 * root.scaleUnit
            background: Rectangle { color: powerButton.hovered ? "#b8343435" : "#820b0b0c"; radius: 10 * root.scaleUnit }
            contentItem: Text { text: "⏻"; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 28 * root.scaleUnit }
            onClicked: powerMenu.open()
            Menu { id: powerMenu; y: -height; x: parent.width - width
                MenuItem { text: "Sleep"; enabled: typeof sddm !== "undefined" && sddm.canSuspend; onTriggered: sddm.suspend() }
                MenuItem { text: "Restart"; enabled: typeof sddm !== "undefined" && sddm.canReboot; onTriggered: sddm.reboot() }
                MenuItem { text: "Shut down"; enabled: typeof sddm !== "undefined" && sddm.canPowerOff; onTriggered: sddm.powerOff() }
            }
        }
    }
}
