import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Layouts

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#050505"

    property var accounts: typeof userModel === "undefined" ? null : userModel
    property var sessions: typeof sessionModel === "undefined" ? null : sessionModel
    property var layouts: typeof keyboard === "undefined" ? null : keyboard
    property var greeter: typeof sddm === "undefined" ? null : sddm
    property date clockTime: new Date()
    property bool signingIn: false
    property bool revealPassword: false
    property string loginError: ""
    readonly property string userName: account.currentValue || ""
    readonly property string displayName: userName === "yhvhan" ? "Yhvhan" : account.currentText
    readonly property bool split: width / height >= 1.42 && width >= 840
    readonly property real unit: Math.min(width / (split ? 1920 : 690), height / (split ? 1080 : 1010))
    readonly property color primary: "#f4f4f4"
    readonly property color muted: "#bcbcbc"
    readonly property string typeface: "DejaVu Sans"

    function submit() {
        if (!greeter || signingIn || !userName || session.currentIndex < 0)
            return;
        loginError = "";
        revealPassword = false;
        signingIn = true;
        greeter.login(userName, password.text, session.currentIndex);
        password.clear();
    }

    function resetPassword() {
        password.clear();
        revealPassword = false;
        loginError = "";
        password.forceActiveFocus();
    }

    Component.onCompleted: Qt.callLater(function () {
        password.forceActiveFocus();
    })
    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: root.clockTime = new Date()
    }
    Connections {
        target: root.greeter
        function onLoginFailed() {
            root.signingIn = false;
            root.resetPassword();
            root.loginError = "Couldn’t sign in. Try again.";
        }
    }

    component Label: Text {
        color: root.primary
        font.family: root.typeface
        font.pixelSize: 20 * root.unit
        renderType: Text.NativeRendering
    }
    component Choice: Controls.ComboBox {
        id: control
        font.family: root.typeface
        font.pixelSize: 19 * root.unit
        leftPadding: 8 * root.unit
        rightPadding: (count > 1 ? 30 : 8) * root.unit
        topPadding: 4 * root.unit
        bottomPadding: 4 * root.unit
        hoverEnabled: true
        enabled: count > 0 && !root.signingIn

        background: Rectangle {
            color: control.hovered || control.popup.visible ? "#252525" : "transparent"
            radius: 7 * root.unit
            border.width: control.visualFocus ? 1 : 0
            border.color: "#a8a8a8"
        }
        contentItem: Label {
            text: control.displayText
            font: control.font
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        indicator: Label {
            visible: control.count > 1
            x: control.width - 23 * root.unit
            anchors.verticalCenter: parent.verticalCenter
            text: "⌄"
            font.pixelSize: 20 * root.unit
        }
        delegate: Controls.ItemDelegate {
            required property int index
            width: ListView.view ? ListView.view.width : control.width
            text: control.textAt(index)
            font: control.font
            highlighted: control.highlightedIndex === index
            contentItem: Label {
                text: parent.text
                font: parent.font
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                color: parent.highlighted ? "#363636" : "transparent"
            }
        }
        popup: Controls.Popup {
            y: control.height + 3
            width: Math.max(control.width, 176 * root.unit)
            padding: 4
            closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
            contentItem: ListView {
                clip: true
                implicitHeight: Math.min(contentHeight, root.height * 0.28)
                model: control.popup.visible ? control.delegateModel : null
                currentIndex: control.highlightedIndex
                Controls.ScrollIndicator.vertical: Controls.ScrollIndicator {}
            }
            background: Rectangle {
                color: "#171717"
                radius: 8
                border.color: "#686868"
            }
        }
    }
    component LineButton: Controls.Button {
        id: button
        hoverEnabled: true
        padding: 7 * root.unit
        font.family: root.typeface
        font.pixelSize: 18 * root.unit
        contentItem: Label {
            text: button.text
            font: button.font
            opacity: button.enabled ? 1 : 0.45
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            color: button.down ? "#333333" : button.hovered ? "#232323" : "transparent"
            radius: 8 * root.unit
            border.width: button.visualFocus ? 1 : 0
            border.color: "#b8b8b8"
        }
    }

    Image {
        anchors.fill: parent
        source: "wallpaper.png"
        fillMode: Image.PreserveAspectCrop
        smooth: true
    }
    Column {
        id: brand
        x: root.split ? root.width * 0.106 : (root.width - width) / 2
        y: root.split ? root.height * 0.397 : root.height * 0.088
        width: root.split ? root.width * 0.344 : 440 * root.unit
        spacing: 30 * root.unit
        Image {
            width: parent.width
            height: width * 89 / 578
            source: "wordmark.png"
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 90 * root.unit
            height: 1
            color: "#c6c6c6"
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "A SPACE OF YOUR OWN"
            font.pixelSize: (root.split ? 23 : 18) * root.unit
            font.letterSpacing: (root.split ? 7 : 5) * root.unit
        }
    }

    Label {
        anchors.right: frame.right
        anchors.bottom: frame.top
        anchors.bottomMargin: 35 * root.unit
        text: Qt.formatTime(root.clockTime, "hh:mm AP")
        font.pixelSize: 27 * root.unit
        font.letterSpacing: 4 * root.unit
        visible: root.split
    }
    Rectangle {
        id: frame
        objectName: "loginFrame"
        x: root.split ? root.width * 0.565 : (root.width - width) / 2
        y: root.split ? root.height * 0.222 : root.height * 0.285
        width: root.split ? root.width * 0.321 : 570 * root.unit
        height: 566 * root.unit
        radius: 32 * root.unit
        color: "#e6101010"
        border.color: "#bcbcbc"
        border.width: Math.max(1, root.unit)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 42 * root.unit
            spacing: 11 * root.unit

            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 124 * root.unit
                Layout.preferredHeight: Layout.preferredWidth
                Canvas {
                    id: portrait
                    objectName: "profileImage"
                    anchors.fill: parent
                    anchors.margins: Math.max(1, root.unit)
                    readonly property url path: Qt.resolvedUrl("profile.png")
                    property bool loaded: false
                    onImageLoaded: {
                        loaded = isImageLoaded(path);
                        requestPaint();
                    }
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    Component.onCompleted: loadImage(path)
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        if (!loaded)
                            return;
                        ctx.beginPath();
                        ctx.arc(width / 2, height / 2, width / 2, 0, Math.PI * 2);
                        ctx.clip();
                        ctx.drawImage(path, 0, 0, width, height);
                    }
                    // Re-evaluate when the asynchronous image load completes.
                    visible: root.userName === "yhvhan" && loaded
                }
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: portrait.visible ? "transparent" : "#141414"
                    border.color: "#d1d1d1"
                    border.width: Math.max(1, root.unit)
                    Label {
                        anchors.centerIn: parent
                        visible: !portrait.visible
                        text: (root.displayName || "?").charAt(0).toUpperCase()
                        font.pixelSize: 56 * root.unit
                    }
                }
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                text: "Welcome back"
                color: root.muted
                font.pixelSize: 22 * root.unit
                font.letterSpacing: 3 * root.unit
            }
            Choice {
                id: account
                objectName: "account"
                Accessible.name: "User account"
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: frame.width - 84 * root.unit
                model: root.accounts
                textRole: "name"
                valueRole: "name"
                currentIndex: root.accounts && root.accounts.lastIndex >= 0 ? root.accounts.lastIndex : count > 0 ? 0 : -1
                displayText: root.displayName
                font.pixelSize: 36 * root.unit
                font.weight: Font.DemiBold
                onActivated: root.resetPassword()
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 12 * root.unit
                Layout.preferredHeight: 64 * root.unit
                spacing: 0
                Controls.TextField {
                    id: password
                    objectName: "password"
                    Accessible.name: "Password"
                    enabled: !root.signingIn
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    leftPadding: 26 * root.unit
                    rightPadding: 62 * root.unit
                    color: root.primary
                    placeholderText: "Password"
                    placeholderTextColor: "#ababab"
                    font.family: root.typeface
                    font.pixelSize: 22 * root.unit
                    font.letterSpacing: 2 * root.unit
                    echoMode: root.revealPassword ? TextInput.Normal : TextInput.Password
                    inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                    selectByMouse: true
                    onAccepted: root.submit()
                    onTextEdited: root.loginError = ""
                    Keys.onEscapePressed: root.revealPassword = false
                    background: Rectangle {
                        color: "#0b0b0b"
                        radius: 13 * root.unit
                        border.width: Math.max(1, root.unit)
                        border.color: password.activeFocus ? "#ededed" : "#888888"
                    }
                    LineButton {
                        id: reveal
                        objectName: "revealPassword"
                        width: 52 * root.unit
                        height: parent.height - 6 * root.unit
                        anchors.right: parent.right
                        anchors.rightMargin: 5 * root.unit
                        anchors.verticalCenter: parent.verticalCenter
                        Accessible.name: root.revealPassword ? "Hide password" : "Show password"
                        onClicked: {
                            root.revealPassword = !root.revealPassword;
                            password.forceActiveFocus();
                        }
                        contentItem: Canvas {
                            id: eyeIcon
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()
                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.reset();
                                ctx.translate(width / 2, height / 2);
                                ctx.scale(root.unit, root.unit);
                                ctx.strokeStyle = "#e3e3e3";
                                ctx.lineWidth = 1.5;
                                ctx.beginPath();
                                ctx.moveTo(-13, 0);
                                ctx.quadraticCurveTo(0, -17, 13, 0);
                                ctx.quadraticCurveTo(0, 17, -13, 0);
                                ctx.stroke();
                                ctx.beginPath();
                                ctx.arc(0, 0, 4, 0, Math.PI * 2);
                                ctx.stroke();
                                if (root.revealPassword) {
                                    ctx.beginPath();
                                    ctx.moveTo(-11, 9);
                                    ctx.lineTo(11, -9);
                                    ctx.stroke();
                                }
                            }
                            Connections {
                                target: root
                                function onRevealPasswordChanged() {
                                    eyeIcon.requestPaint();
                                }
                            }
                        }
                    }
                }
            }
            Controls.Button {
                id: signIn
                objectName: "signIn"
                hoverEnabled: true
                Layout.fillWidth: true
                Layout.preferredHeight: 64 * root.unit
                Layout.topMargin: 13 * root.unit
                text: root.signingIn ? "Signing in…" : "Sign in  →"
                enabled: !!root.userName && session.currentIndex >= 0 && !root.signingIn
                onClicked: root.submit()
                background: Rectangle {
                    color: signIn.down ? "#aeaeae" : signIn.hovered ? "#f4f4f4" : "#d4d4d4"
                    opacity: signIn.enabled ? 1 : 0.68
                    radius: 13 * root.unit
                    border.width: signIn.visualFocus ? 2 : 0
                    border.color: "#ffffff"
                    Behavior on color {
                        ColorAnimation {
                            duration: 110
                        }
                    }
                }
                contentItem: Label {
                    text: signIn.text
                    color: "#101010"
                    font.pixelSize: 23 * root.unit
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.25 * root.unit
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            Label {
                Layout.fillWidth: true
                visible: root.loginError.length > 0
                text: root.loginError
                font.pixelSize: 16 * root.unit
                horizontalAlignment: Text.AlignHCenter
                Accessible.ignored: !visible
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4 * root.unit
                Choice {
                    id: session
                    objectName: "session"
                    Layout.maximumWidth: frame.width * 0.56
                    model: root.sessions
                    textRole: "name"
                    currentIndex: root.sessions && root.sessions.lastIndex >= 0 ? root.sessions.lastIndex : count > 0 ? 0 : -1
                    displayText: count > 0 ? currentText : "No sessions"
                    Accessible.name: "Desktop session"
                }
                Item {
                    Layout.fillWidth: true
                }
                Label {
                    text: "Caps Lock"
                    visible: !!root.layouts && root.layouts.capsLock
                    font.pixelSize: 15 * root.unit
                    color: root.muted
                }
                Choice {
                    id: layout
                    objectName: "keyboardLayout"
                    Accessible.name: "Keyboard layout"
                    model: root.layouts ? root.layouts.layouts : null
                    textRole: "shortName"
                    currentIndex: root.layouts && count > 0 ? root.layouts.currentLayout : -1
                    displayText: currentText.toUpperCase()
                    visible: count > 0
                    onActivated: function (index) {
                        root.layouts.currentLayout = index;
                    }
                }
            }
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 38 * root.unit
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 35 * root.unit
        spacing: 16 * root.unit
        LineButton {
            text: "↻  Restart"
            enabled: !!root.greeter && root.greeter.canReboot
            onClicked: root.greeter.reboot()
        }
        LineButton {
            text: "⏻  Power"
            enabled: !!root.greeter && root.greeter.canPowerOff
            onClicked: root.greeter.powerOff()
        }
    }
}
