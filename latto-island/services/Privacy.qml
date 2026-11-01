pragma Singleton

import QtQuick
import Quickshell.Io

// Privacy indicators: microphone capture, camera use and screen recording.
// The microphone is re-checked on every PulseAudio/PipeWire source-output
// event; the camera and screen recorders are polled.
QtObject {
    id: root

    property bool microphone: false
    property bool camera: false
    property bool recording: false
    readonly property bool active: Settings.privacyIndicators && (microphone || camera || recording)

    // One probe prints "<mic streams> <recording 0|1> <camera 0|1>".
    //  - mic: capture streams on real inputs; monitor sources (audio
    //    visualizers, screen recorders capturing system sound) do not count.
    //  - camera: any of the user's processes holding a /dev/video* device.
    //  - recording: known screen recorders. Process names are truncated to
    //    15 characters, hence "gpu-screen-reco".
    readonly property string script: [
        "mons=$(pactl list short sources 2>/dev/null | awk '$2 ~ /\\.monitor$/ {print $1}' | tr '\\n' ' ')",
        "mic=$(pactl list short source-outputs 2>/dev/null | awk -v m=\"$mons\" 'BEGIN { n = split(m, a, \" \"); for (i = 1; i <= n; i++) mon[a[i]] = 1 } !($2 in mon)' | wc -l)",
        "rec=0; for p in wf-recorder wl-screenrec gpu-screen-reco obs; do pgrep -x \"$p\" >/dev/null && rec=1; done",
        "cam=$(find /proc/[0-9]*/fd -maxdepth 1 -lname '/dev/video*' 2>/dev/null | head -n1 | wc -l)",
        "echo \"$mic $rec $cam\""
    ].join("\n")

    property bool refreshPending: false

    function refresh() {
        if (probe.running)
            refreshPending = true;
        else
            probe.running = true;
    }

    property Process probe: Process {
        command: ["sh", "-c", root.script]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split(/\s+/);
                if (parts.length !== 3)
                    return;
                root.microphone = parseInt(parts[0]) > 0;
                root.recording = parts[1] === "1";
                root.camera = parts[2] === "1";
            }
        }
        onExited: {
            if (root.refreshPending) {
                root.refreshPending = false;
                Qt.callLater(root.refresh);
            }
        }
    }

    // Streams starting or stopping on any source.
    property Process audioEvents: Process {
        running: Settings.privacyIndicators
        command: ["pactl", "subscribe"]
        stdout: SplitParser {
            onRead: line => {
                if (line.includes("source-output"))
                    root.refresh();
            }
        }
    }

    property Timer timer: Timer {
        interval: 1500
        running: Settings.privacyIndicators
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
