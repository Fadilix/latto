import QtQuick
import Quickshell
import Quickshell.Bluetooth as Bluez
import "../../latto-island/services"
import "../../latto-island/theme"

Item {
    id: root
    property var scanningAdapter: null
    readonly property bool blocked: Bluetooth.available
        && Bluetooth.adapter.state === Bluez.BluetoothAdapterState.Blocked
    readonly property bool switching: Bluetooth.available
        && (Bluetooth.adapter.state === Bluez.BluetoothAdapterState.Enabling
            || Bluetooth.adapter.state === Bluez.BluetoothAdapterState.Disabling)
    function scan() {
        const adapter = Bluetooth.adapter;
        if (adapter && adapter.enabled && !adapter.discovering) {
            scanningAdapter = adapter;
            adapter.discovering = true;
        }
    }
    Component.onCompleted: scan()
    Component.onDestruction: {
        if (scanningAdapter) scanningAdapter.discovering = false;
    }
    Connections {
        target: Bluetooth
        function onEnabledChanged() { if (Bluetooth.enabled) root.scan(); }
    }
    Row {
        id: header
        width: parent.width
        spacing: 8
        Text {
            width: parent.width - power.width - 8
            anchors.verticalCenter: parent.verticalCenter
            text: "Bluetooth"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
        BarButton {
            id: power
            text: root.blocked ? "Blocked" : root.switching
                ? (Bluetooth.adapter.state === Bluez.BluetoothAdapterState.Enabling ? "Turning on…" : "Turning off…")
                : Bluetooth.enabled ? "On" : "Off"
            enabled: Bluetooth.available && !root.blocked && !root.switching
            icon: "bluetooth"
            active: Bluetooth.enabled
            tint: Bluetooth.enabled ? Theme.accent : Theme.textSecondary
            onClicked: Bluetooth.toggle()
        }
    }
    Text {
        id: subtitle
        anchors.top: header.bottom
        anchors.topMargin: 8
        width: parent.width
        text: !Bluetooth.available ? "No Bluetooth adapter" : root.blocked ? "Bluetooth is blocked · check airplane mode / radio switch"
            : root.switching ? "Changing adapter power…" : !Bluetooth.enabled ? "Bluetooth is off"
            : Bluetooth.adapter.discovering ? "Looking for nearby devices…" : "Available devices"
        wrapMode: Text.WordWrap
        color: root.blocked ? Theme.orange : Theme.textTertiary
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }
    ListView {
        id: devices
        anchors.top: subtitle.bottom
        anchors.topMargin: 10
        anchors.bottom: settings.top
        anchors.bottomMargin: 8
        width: parent.width
        clip: true
        spacing: 4
        visible: Bluetooth.enabled
        model: Bluetooth.devices.filter(device => device.adapter === Bluetooth.adapter)
        delegate: Rectangle {
            id: deviceRow
            required property var modelData
            readonly property bool busy: modelData.pairing
                || modelData.state === Bluez.BluetoothDeviceState.Connecting
                || modelData.state === Bluez.BluetoothDeviceState.Disconnecting
            property bool connectAfterPair: false
            width: devices.width
            height: 56
            radius: 10
            color: pointer.containsMouse ? Theme.surfaceRaised : "transparent"
            Connections {
                target: deviceRow.modelData
                function onPairedChanged() {
                    if (deviceRow.connectAfterPair && deviceRow.modelData.paired) {
                        deviceRow.connectAfterPair = false;
                        deviceRow.modelData.connect();
                    }
                }
            }
            BarIcon {
                id: icon
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                name: "bluetooth"
                color: deviceRow.modelData.connected ? Theme.accent : Theme.textSecondary
            }
            Column {
                anchors.left: icon.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Text {
                    width: parent.width
                    text: deviceRow.modelData.name || deviceRow.modelData.deviceName || deviceRow.modelData.address
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
                Text {
                    width: parent.width
                    text: deviceRow.modelData.pairing ? "Pairing…"
                        : deviceRow.busy ? Bluez.BluetoothDeviceState.toString(deviceRow.modelData.state)
                        : deviceRow.modelData.connected ? "Connected · click to disconnect" + (deviceRow.modelData.batteryAvailable ? " · " + Math.round(deviceRow.modelData.battery * 100) + "%" : "")
                        : deviceRow.modelData.paired ? "Paired · click to connect" : "Click to pair"
                    elide: Text.ElideRight
                    color: deviceRow.modelData.connected ? Theme.accent : Theme.textTertiary
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }
            }
            MouseArea {
                id: pointer
                anchors.fill: parent
                hoverEnabled: true
                enabled: !deviceRow.busy
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (deviceRow.modelData.connected) deviceRow.modelData.disconnect();
                    else if (deviceRow.modelData.paired) deviceRow.modelData.connect();
                    else {
                        deviceRow.connectAfterPair = true;
                        deviceRow.modelData.pair();
                    }
                }
            }
        }
        Text {
            anchors.centerIn: parent
            visible: devices.count === 0
            text: "No devices found"
            color: Theme.textTertiary
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }
    }
    BarButton {
        id: settings
        anchors.bottom: parent.bottom
        width: parent.width
        icon: "settings"
        text: "Device settings / pairing help"
        onClicked: Quickshell.execDetached(["blueman-manager"])
    }
}
