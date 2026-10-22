import QtQuick
import Quickshell.Io

// Listens to `udevadm monitor` for one subsystem and emits deviceChanged() on
// every event, so services can react immediately instead of polling.
// Restarts itself if udevadm exits.
Process {
    id: root

    required property string subsystem

    signal deviceChanged()

    running: true
    command: ["udevadm", "monitor", "--udev", "--subsystem-match=" + subsystem]

    // udevadm writes the newline *before* each event, so a complete line only
    // arrives when the next event starts. Any output at all means something
    // changed, so react to every read instead of parsing lines.
    stdout: SplitParser {
        onRead: root.deviceChanged()
    }

    onExited: restartTimer.start()

    property Timer restartTimer: Timer {
        interval: 2000
        onTriggered: root.running = true
    }
}
