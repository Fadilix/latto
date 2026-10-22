pragma Singleton

import QtQuick
import Quickshell.Io

// Upcoming events from khal (https://github.com/pimutils/khal), enabled with
// calendarEnabled. The month grid itself is drawn by CalendarTab.
QtObject {
    id: root

    // [{ time, title }]
    property var events: []

    function parse(text) {
        return text.split("\n")
            .filter(line => line.indexOf("|") > 0)
            .slice(0, 6)
            .map(line => {
                const bar = line.indexOf("|");
                return { time: line.slice(0, bar), title: line.slice(bar + 1) };
            });
    }

    property Process probe: Process {
        command: ["khal", "list", "today", "3d", "--format", "{start-time}|{title}", "--day-format", ""]
        stdout: StdioCollector {
            onStreamFinished: root.events = root.parse(this.text)
        }
    }

    property Timer timer: Timer {
        interval: 300000
        running: Settings.calendarEnabled
        repeat: true
        triggeredOnStart: true
        onTriggered: root.probe.running = true
    }
}
