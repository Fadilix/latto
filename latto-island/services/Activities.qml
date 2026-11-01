pragma Singleton

import QtQuick

// Queue of transient alerts (volume, charging, Bluetooth, ...). The island
// shows the highest-priority entry that has not expired.
// An entry with durationMs 0 stays until dismiss() is called.
QtObject {
    id: root

    // [{ kind, priority, data: { label, value, ... }, expiresAt, timed }]
    property var entries: []

    readonly property var current: {
        const now = Date.now();
        let best = null;
        for (const entry of entries) {
            if (entry.expiresAt > 0 && entry.expiresAt <= now)
                continue;
            if (!best || entry.priority > best.priority)
                best = entry;
        }
        return best;
    }

    function show(kind, priority, data, durationMs) {
        const expiresAt = durationMs > 0 ? Date.now() + durationMs : 0;
        const others = entries.filter(entry => entry.kind !== kind);
        entries = others.concat([{ kind: kind, priority: priority, data: data, expiresAt: expiresAt, timed: durationMs > 0 }]);
    }

    // While held (e.g. the pointer is over it) an entry does not expire. On
    // release a timed entry gets graceMs more before it goes.
    function hold(kind, held, graceMs) {
        if (!entries.some(entry => entry.kind === kind))
            return;
        entries = entries.map(entry => {
            if (entry.kind !== kind || !entry.timed)
                return entry;
            return Object.assign({}, entry, { expiresAt: held ? 0 : Date.now() + (graceMs || 2500) });
        });
    }

    // The live entry of this kind, or null.
    function find(kind) {
        const now = Date.now();
        for (const entry of entries) {
            if (entry.kind === kind && (entry.expiresAt === 0 || entry.expiresAt > now))
                return entry;
        }
        return null;
    }

    function dismiss(kind) {
        if (entries.some(entry => entry.kind === kind))
            entries = entries.filter(entry => entry.kind !== kind);
    }

    // Drops expired entries. Reassigning `entries` is what re-evaluates `current`.
    property Timer pruner: Timer {
        interval: 250
        repeat: true
        running: root.entries.length > 0
        onTriggered: {
            const now = Date.now();
            const alive = root.entries.filter(entry => entry.expiresAt === 0 || entry.expiresAt > now);
            if (alive.length !== root.entries.length)
                root.entries = alive;
        }
    }
}
