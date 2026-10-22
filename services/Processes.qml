pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Apps ranked by memory use or by current CPU use, with every process of an
// app counted together (see scripts/). Each ranking is sampled only while a
// view watches it: call watch(kind) when shown and unwatch(kind) when hidden,
// with kind "memory" or "cpu".
QtObject {
    id: root

    // [{ id, name, icon, count, kib }], largest first
    property var byMemory: []
    // [{ id, name, icon, count, percent }], busiest first. percent is a share
    // of the whole machine, so all apps together add up to at most 100.
    property var byCpu: []

    property int memoryWatchers: 0
    property int cpuWatchers: 0

    readonly property int listLength: 12

    function watch(kind) {
        if (kind === "cpu") cpuWatchers++;
        else memoryWatchers++;
    }

    function unwatch(kind) {
        if (kind === "cpu") cpuWatchers = Math.max(0, cpuWatchers - 1);
        else memoryWatchers = Math.max(0, memoryWatchers - 1);
    }

    // --- display names and icons ---------------------------------------

    // Desktop entries load lazily; touching the list starts loading them.
    readonly property int knownApps: DesktopEntries.applications.values.length

    // Executable -> { name, icon }. Cleared when the set of apps changes.
    property var appCache: ({})
    onKnownAppsChanged: appCache = {}

    // "zen-bin" -> "zen", "electron-wrapped" -> "electron"
    function baseName(executable) {
        return executable.replace(/[-.](bin|wrapped|real)$/, "");
    }

    function appFor(executable) {
        if (appCache[executable])
            return appCache[executable];
        const base = baseName(executable);
        const entry = DesktopEntries.heuristicLookup(base);
        let icon = entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : "";
        if (icon === "")
            icon = Quickshell.iconPath(base.toLowerCase(), true);
        const app = { name: entry && entry.name ? entry.name : base, icon: icon };
        appCache[executable] = app;
        return app;
    }

    function describe(executable, extra) {
        const app = appFor(executable);
        return Object.assign({ id: executable, name: app.name, icon: app.icon }, extra);
    }

    // --- memory ----------------------------------------------------------

    function ingestMemory(text) {
        byMemory = text.trim().split("\n")
            .filter(line => line.length > 0)
            .map(line => {
                const parts = line.split("\t");
                return describe(parts[2] || "", {
                    count: parseInt(parts[1]) || 1,
                    kib: parseInt(parts[0]) || 0
                });
            });
    }

    property Process memorySampler: Process {
        command: ["sh", Quickshell.shellDir + "/services/scripts/top-memory.sh", String(root.listLength)]
        stdout: StdioCollector {
            onStreamFinished: root.ingestMemory(this.text)
        }
    }

    property Timer memoryTimer: Timer {
        interval: 2000
        repeat: true
        running: root.memoryWatchers > 0
        triggeredOnStart: true
        onTriggered: root.memorySampler.running = true
    }

    // --- CPU -------------------------------------------------------------

    // The previous sample: { total, ticks: { pid: ticks } }.
    property var lastCpuSample: null

    function ingestCpu(text) {
        let total = 0;
        const ticks = {};
        const names = {};
        for (const line of text.trim().split("\n")) {
            const parts = line.split("\t");
            if (parts[0] === "T") {
                total = Number(parts[1]);
            } else if (parts.length === 3) {
                ticks[parts[0]] = Number(parts[1]);
                names[parts[0]] = parts[2];
            }
        }

        const previous = lastCpuSample;
        lastCpuSample = { total: total, ticks: ticks };
        if (!previous || total <= previous.total)
            return;

        // Busy ticks per app since the last sample, for processes in both.
        const elapsed = total - previous.total;
        const busy = {};
        const count = {};
        for (const pid in ticks) {
            if (!(pid in previous.ticks))
                continue;
            const name = names[pid];
            busy[name] = (busy[name] || 0) + Math.max(0, ticks[pid] - previous.ticks[pid]);
            count[name] = (count[name] || 0) + 1;
        }

        byCpu = Object.keys(busy)
            .map(name => ({ name: name, percent: busy[name] / elapsed * 100 }))
            .filter(app => app.percent >= 0.05)
            .sort((a, b) => b.percent - a.percent)
            .slice(0, listLength)
            .map(app => describe(app.name, { count: count[app.name], percent: app.percent }));
    }

    property Process cpuSampler: Process {
        command: ["sh", Quickshell.shellDir + "/services/scripts/cpu-sample.sh"]
        stdout: StdioCollector {
            onStreamFinished: root.ingestCpu(this.text)
        }
    }

    property Timer cpuTimer: Timer {
        interval: 2000
        repeat: true
        running: root.cpuWatchers > 0
        triggeredOnStart: true
        onTriggered: root.cpuSampler.running = true
        // A fresh start measures from its own first sample.
        onRunningChanged: if (!running) root.lastCpuSample = null
    }
}
