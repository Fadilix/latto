pragma Singleton

import QtQuick
import Quickshell.Io

// CPU, memory, network, disk and temperature, read from /proc and sysfs.
// CPU and network rates come from the difference between two samples.
QtObject {
    id: root

    readonly property int historyLength: 60

    property real cpu: 0               // percent
    property real memory: 0            // percent
    property real memoryUsedGiB: 0
    property real memoryTotalGiB: 0
    property real disk: 0              // percent
    property real diskUsedGiB: 0
    property real diskTotalGiB: 0
    property real downRate: 0          // bytes per second
    property real upRate: 0
    property real temperature: 0       // degrees C, 0 when unavailable

    property var cpuHistory: []
    property var memoryHistory: []
    property var downHistory: []
    property var upHistory: []

    // Each line prints one sample: cpu, mem, net, disk and temp.
    readonly property string script: [
        "awk '/^cpu /{t=0; for(i=2;i<=9;i++) t+=$i; print \"cpu\", t, $5+$6}' /proc/stat",
        "awk '/^MemTotal/{t=$2} /^MemAvailable/{a=$2} END{print \"mem\", t, a}' /proc/meminfo",
        "awk 'NR>2{sub(\":\", \" \"); if($1!=\"lo\"){rx+=$2; tx+=$10}} END{print \"net\", rx, tx}' /proc/net/dev",
        "df -Pk / | awk 'NR==2{print \"disk\", $3, $2}'",
        "echo temp $(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0)"
    ].join("; ")

    property var previous: null
    property double previousTime: 0

    function append(history, value) {
        return history.slice(-(historyLength - 1)).concat([value]);
    }

    function ingest(output) {
        const values = {};
        for (const line of output.trim().split("\n")) {
            const parts = line.trim().split(/\s+/);
            values[parts[0]] = parts.slice(1).map(Number);
        }

        const now = Date.now();
        if (values.mem) {
            const total = values.mem[0];
            const available = values.mem[1];
            memoryTotalGiB = total / 1048576;
            memoryUsedGiB = (total - available) / 1048576;
            memory = total > 0 ? (total - available) / total * 100 : 0;
        }
        if (values.disk) {
            const used = values.disk[0];
            const total = values.disk[1];
            diskUsedGiB = used / 1048576;
            diskTotalGiB = total / 1048576;
            disk = total > 0 ? used / total * 100 : 0;
        }
        if (values.temp)
            temperature = values.temp[0] / 1000;

        if (previous && values.cpu) {
            const dTotal = values.cpu[0] - previous.cpu[0];
            const dIdle = values.cpu[1] - previous.cpu[1];
            cpu = dTotal > 0 ? (1 - dIdle / dTotal) * 100 : 0;
        }
        if (previous && values.net) {
            const seconds = Math.max(0.001, (now - previousTime) / 1000);
            downRate = Math.max(0, (values.net[0] - previous.net[0]) / seconds);
            upRate = Math.max(0, (values.net[1] - previous.net[1]) / seconds);
        }
        if (values.cpu && values.net)
            previous = { cpu: values.cpu, net: values.net };
        previousTime = now;

        cpuHistory = append(cpuHistory, cpu);
        memoryHistory = append(memoryHistory, memory);
        downHistory = append(downHistory, downRate);
        upHistory = append(upHistory, upRate);
    }

    property Process sampler: Process {
        command: ["sh", "-c", root.script]
        stdout: StdioCollector {
            onStreamFinished: root.ingest(this.text)
        }
    }

    property Timer timer: Timer {
        interval: Settings.statsInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.sampler.running = true
    }
}
