pragma Singleton

import QtQuick
import Quickshell.Io

// First battery under /sys/class/power_supply. Re-read on every udev
// power_supply event (so plugging in shows at once), plus a slow poll to
// catch percentage changes that arrive without an event.
QtObject {
    id: root

    property bool available: false
    property int percent: 0
    property string status: ""
    readonly property bool charging: status === "Charging"

    property bool refreshPending: false

    function refresh() {
        if (reader.running)
            refreshPending = true;
        else
            reader.running = true;
    }

    property Process reader: Process {
        command: ["sh", "-c", "b=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n1); [ -n \"$b\" ] && cat \"$b/capacity\" \"$b/status\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split("\n");
                root.available = parts.length === 2;
                if (root.available) {
                    root.percent = parseInt(parts[0]) || 0;
                    root.status = parts[1].trim();
                }
            }
        }
        onExited: {
            if (root.refreshPending) {
                root.refreshPending = false;
                Qt.callLater(root.refresh);
            }
        }
    }

    property UdevMonitor monitor: UdevMonitor {
        subsystem: "power_supply"
        onDeviceChanged: root.refresh()
    }

    property Timer timer: Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
