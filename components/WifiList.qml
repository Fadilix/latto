import QtQuick
import "../services"
import "../theme"

// Nearby Wi-Fi networks to pick from, opened from the Overview tab. Saved and
// open networks connect on click; a new secured network asks for its password
// inline, and an enterprise (802.1X) one for a username and password. When a
// network wants a web sign-in (a captive portal), its row offers "Sign in".
Item {
    id: root

    signal back()

    // The network whose password row is open, or "".
    property string askingFor: ""

    Component.onCompleted: Network.watch()
    Component.onDestruction: {
        Network.unwatch();
        if (askingFor !== "")
            IslandState.release();
    }

    function choose(network) {
        if (network.active)
            return;
        if (network.known || !network.secure) {
            closePassword();
            Network.connect(network, "");
        } else {
            openPassword(network.ssid);
        }
    }

    function openPassword(ssid) {
        if (askingFor === "")
            IslandState.holdOpen();
        askingFor = ssid;
    }

    function closePassword() {
        if (askingFor !== "")
            IslandState.release();
        askingFor = "";
    }

    // A rounded text field with a placeholder.
    component Field: Rectangle {
        id: field

        property alias input: input
        property string placeholder: ""
        property bool secret: false

        height: 26
        radius: 8
        color: Theme.island
        border.color: input.activeFocus ? Theme.blue : Theme.border
        border.width: 1

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            echoMode: field.secret ? TextInput.Password : TextInput.Normal
            passwordCharacter: "\u2022"
            color: Theme.text
            selectionColor: Theme.blue
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall + 1
            clip: true

            Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text === ""
                text: field.placeholder
                color: Theme.textTertiary
                font.pixelSize: Theme.fontSmall + 1
            }
        }
    }

    // Header: back, title, rescan and the radio switch.
    Item {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 28

        IslandButton {
            id: backButton
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            icon: "chevronLeft"
            iconSize: 16
            color: Theme.textSecondary
            onClicked: {
                root.closePassword();
                root.back();
            }
        }
        Label {
            anchors.left: backButton.right
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            text: "Wi-Fi"
            font.pixelSize: Theme.fontBody + 1
            font.weight: Font.DemiBold
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            IslandButton {
                id: rescanButton
                anchors.verticalCenter: parent.verticalCenter
                visible: Network.wifiEnabled
                icon: "refresh"
                iconSize: 14
                color: Theme.textSecondary
                onClicked: Network.scan(true)

                RotationAnimation on rotation {
                    running: Network.scanning
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) rescanButton.rotation = 0
                }
            }

            // On/off switch.
            Rectangle {
                id: radioSwitch
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                height: 20
                radius: 10
                color: Network.wifiEnabled ? Theme.blue : Theme.surfaceRaised
                Behavior on color { ColorAnimation { duration: Theme.fadeDuration } }

                Rectangle {
                    x: Network.wifiEnabled ? parent.width - width - 2 : 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16
                    radius: 8
                    color: Theme.text
                    Behavior on x {
                        NumberAnimation { duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Network.toggleWifi()
                }
                Accessible.role: Accessible.CheckBox
                Accessible.name: "Wi-Fi"
                Accessible.checked: Network.wifiEnabled
            }
        }
    }

    Label {
        anchors.centerIn: list
        visible: !Network.wifiEnabled || Network.networks.length === 0
        text: !Network.wifiEnabled ? "Wi-Fi is off" : Network.scanning ? "Looking for networks…" : "No networks found"
        color: Theme.textTertiary
    }

    ListView {
        id: list
        anchors.top: header.bottom
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: Network.wifiEnabled
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        model: Network.networks

        delegate: Item {
            id: row

            required property var modelData
            readonly property bool asking: root.askingFor === modelData.ssid
            readonly property bool busy: Network.connecting === modelData.ssid
            readonly property bool failed: Network.failedSsid === modelData.ssid
            // A username is needed too for an enterprise network not yet saved.
            readonly property bool needsUser: modelData.enterprise && !modelData.known

            width: ListView.view.width
            height: !asking ? 32 : needsUser ? 96 : 64
            Behavior on height {
                NumberAnimation { duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.smoothCurve }
            }

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: row.asking || rowHover.hovered ? Theme.surface : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.fadeDuration } }
            }
            HoverHandler {
                id: rowHover
            }
            MouseArea {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 32
                enabled: !row.modelData.active && !row.busy
                cursorShape: Qt.PointingHandCursor
                onClicked: root.choose(row.modelData)
            }

            // Signal strength as a filled bar.
            Item {
                id: signalBox
                anchors.left: parent.left
                anchors.leftMargin: 10
                y: 8
                width: 16
                height: 16

                Icon {
                    anchors.centerIn: parent
                    name: "wifi"
                    size: 15
                    color: Theme.surfaceRaised
                }
                Item {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: parent.height * Math.max(0.3, row.modelData.signal / 100)
                    clip: true

                    Icon {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottomMargin: -0.5
                        name: "wifi"
                        size: 15
                        color: row.modelData.active ? Theme.blue : Theme.text
                    }
                }
            }

            Label {
                id: ssidLabel
                anchors.left: signalBox.right
                anchors.leftMargin: 10
                anchors.right: trailing.left
                anchors.rightMargin: 8
                y: 8
                text: row.modelData.ssid
                color: row.modelData.active ? Theme.blue : Theme.text
                font.pixelSize: Theme.fontSmall + 1
                font.weight: row.modelData.active ? Font.DemiBold : Font.Medium
                elide: Text.ElideRight
            }

            // Right side: state and actions.
            Row {
                id: trailing
                anchors.right: parent.right
                anchors.rightMargin: 8
                y: 4
                height: 24
                spacing: 6

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: text !== ""
                    text: row.busy ? "Connecting…"
                        : row.failed ? Network.error
                        : row.modelData.active && Network.portal ? "Needs sign-in"
                        : row.modelData.active ? "Connected"
                        : row.needsUser ? "Username & password"
                        : row.modelData.known ? "Saved"
                        : ""
                    color: row.failed ? Theme.red : row.modelData.active ? Theme.blue : Theme.textTertiary
                    font.pixelSize: Theme.fontCaption + 1
                }
                Spinner {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.busy
                    size: 13
                    color: Theme.blue
                }
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.modelData.secure && !row.busy
                    name: "lock"
                    size: 12
                    color: Theme.textTertiary
                }
                IslandButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.modelData.active && Network.portal
                    text: "Sign in"
                    fontSize: Theme.fontCaption + 1
                    primary: true
                    onClicked: Network.openPortal()
                }
                IslandButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.modelData.active
                    icon: "close"
                    iconSize: 11
                    color: Theme.textSecondary
                    onClicked: Network.disconnect(row.modelData)
                }
            }

            // Sign-in for a new secured network: a username for an enterprise
            // one, then the password. Enter joins, Escape cancels.
            Column {
                id: signIn
                anchors.left: ssidLabel.left
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                spacing: 6
                visible: row.asking
                opacity: row.asking ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.fadeDuration } }

                function join() {
                    if (password.input.text === "" || (row.needsUser && username.input.text === ""))
                        return;
                    Network.connect(row.modelData, password.input.text, row.needsUser ? username.input.text : "");
                    password.input.text = "";
                    root.closePassword();
                }

                function cancel() {
                    password.input.text = "";
                    root.closePassword();
                }

                onVisibleChanged: {
                    if (visible)
                        (row.needsUser ? username : password).input.forceActiveFocus();
                }

                Field {
                    id: username
                    width: parent.width
                    visible: row.needsUser
                    placeholder: "Username"
                    input.KeyNavigation.tab: password.input
                    input.onAccepted: password.input.forceActiveFocus()
                    input.Keys.onEscapePressed: signIn.cancel()
                }

                Item {
                    width: parent.width
                    height: 26

                    Field {
                        id: password
                        anchors.left: parent.left
                        anchors.right: joinButton.left
                        anchors.rightMargin: 6
                        placeholder: "Password"
                        secret: true
                        input.KeyNavigation.backtab: username.input
                        input.onAccepted: signIn.join()
                        input.Keys.onEscapePressed: signIn.cancel()
                    }
                    IslandButton {
                        id: joinButton
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Join"
                        fontSize: Theme.fontSmall
                        primary: true
                        onClicked: signIn.join()
                    }
                }
            }
        }

        displaced: Transition {
            NumberAnimation { properties: "y"; duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.smoothCurve }
        }
    }
}
