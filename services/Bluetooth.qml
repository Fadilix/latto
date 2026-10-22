pragma Singleton

import QtQuick
import Quickshell.Bluetooth

// Bluetooth devices known to the default adapter, and its power switch.
// Connect alerts live in Hud.
QtObject {
    id: root

    readonly property var devices: Bluetooth.devices.values
    readonly property var connected: devices.filter(device => device.connected)

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: available && adapter.enabled

    function toggle() {
        if (!available)
            return;
        const on = !adapter.enabled;
        adapter.enabled = on;
        Activities.show("bluetoothPower", 70, { label: on ? "Bluetooth on" : "Bluetooth off", value: -1, off: !on }, 1800);
    }
}
