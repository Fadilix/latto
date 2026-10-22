import QtQuick
import "../services"
import "../theme"

// Nearby Wi-Fi networks to pick from, opened from the Overview tab. Saved and
// open networks connect on click; a new secured network asks for its password
// inline. Enterprise (802.1X) networks need setting up elsewhere first.
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
        } else if (!network.enterprise) {
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

            width: ListView.view.width
            height: asking ? 64 : 32
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
                cursorShape: row.modelData.enterprise && !row.modelData.known ? Qt.ArrowCursor : Qt.PointingHandCursor
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
                        : row.modelData.active ? "Connected"
                        : row.modelData.enterprise && !row.modelData.known ? "Set up in system settings"
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
                    visible: row.modelData.active
                    icon: "close"
                    iconSize: 11
                    color: Theme.textSecondary
                    onClicked: Network.disconnect(row.modelData)
                }
            }

            // Password entry for a new secured network.
            Item {
                anchors.left: ssidLabel.left
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                height: 26
                visible: row.asking
                opacity: row.asking ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.fadeDuration } }

                Rectangle {
                    id: field
                    anchors.left: parent.left
                    anchors.right: connectButton.left
                    anchors.rightMargin: 6
                    height: parent.height
                    radius: 8
                    color: Theme.island
                    border.color: password.activeFocus ? Theme.blue : Theme.border
                    border.width: 1

                    TextInput {
                        id: password
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        passwordCharacter: "•"
                        color: Theme.text
                        selectionColor: Theme.blue
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall + 1
                        clip: true
                        focus: row.asking
                        onVisibleChanged: if (visible) forceActiveFocus()
                        onAccepted: if (text !== "") connectButton.clicked()
                        Keys.onEscapePressed: {
                            text = "";
                            root.closePassword();
                        }

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: password.text === ""
                            text: "Password"
                            color: Theme.textTertiary
                            font.pixelSize: Theme.fontSmall + 1
                        }
                    }
                }
                IslandButton {
                    id: connectButton
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Join"
                    fontSize: Theme.fontSmall
                    primary: true
                    onClicked: {
                        if (password.text === "")
                            return;
                        Network.connect(row.modelData, password.text);
                        password.text = "";
                        root.closePassword();
                    }
                }
            }
        }

        displaced: Transition {
            NumberAnimation { properties: "y"; duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.smoothCurve }
        }
    }
}
