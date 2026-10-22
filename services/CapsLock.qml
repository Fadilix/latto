pragma Singleton

import QtQuick
import Quickshell.Io

// Caps Lock state from the keyboard LEDs in sysfs. LEDs send no udev events,
// so each LED file is re-read in-process every 120 ms (no processes spawned).
// Caps Lock counts as on if any keyboard's LED is lit.
QtObject {
    id: root

    property bool active: false
    property var ledPaths: []
    property var lit: ({})          // LED path -> bool

    function report(path, on) {
        const next = Object.assign({}, lit);
        next[path] = on;
        lit = next;
        active = Object.values(next).some(value => value);
    }

    property Process finder: Process {
        running: true
        command: ["sh", "-c", "ls -d /sys/class/leds/*::capslock 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.ledPaths = this.text.trim().split("\n").filter(path => path !== "")
        }
    }

    property Instantiator leds: Instantiator {
        model: root.ledPaths
        delegate: FileView {
            required property string modelData
            path: modelData + "/brightness"
            onLoaded: root.report(modelData, text().trim() !== "0")
        }
    }

    property Timer timer: Timer {
        interval: 120
        repeat: true
        running: Settings.capsLockIndicator && root.leds.count > 0
        onTriggered: {
            for (let i = 0; i < root.leds.count; i++)
                root.leds.objectAt(i).reload();
        }
    }
}
