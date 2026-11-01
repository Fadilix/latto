pragma Singleton

import QtQuick
import Quickshell.Io

// Browser downloads still in progress (.crdownload from Chromium, .part from Firefox).
QtObject {
    id: root

    property int count: 0

    property Process probe: Process {
        command: ["sh", "-c", "find \"$HOME/Downloads\" -maxdepth 1 \\( -name '*.crdownload' -o -name '*.part' \\) 2>/dev/null | wc -l"]
        stdout: StdioCollector {
            onStreamFinished: root.count = parseInt(this.text) || 0
        }
    }

    property Timer timer: Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.probe.running = true
    }
}
