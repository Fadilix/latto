pragma Singleton

import QtQuick
import Quickshell.Io

// Clipboard history backed by cliphist. wl-paste feeds every copy into it
// while clipboardEnabled is set.
QtObject {
    id: root

    readonly property int maxItems: 40

    // [{ id, text }], newest first
    property var items: []

    function isId(id) {
        return /^\d+$/.test(id);
    }

    function refresh() {
        if (Settings.clipboardEnabled)
            listing.running = true;
    }

    function copy(id) {
        if (isId(id))
            run("cliphist decode " + id + " | wl-copy");
    }

    function remove(id) {
        if (isId(id))
            run("cliphist list | awk -F '\\t' '$1 == \"" + id + "\"' | cliphist delete");
    }

    function clear() {
        run("cliphist wipe");
    }

    function run(script) {
        action.command = ["sh", "-c", script];
        action.running = true;
    }

    function parse(text) {
        return text.split("\n")
            .filter(line => line.length > 0)
            .slice(0, maxItems)
            .map(line => {
                const tab = line.indexOf("\t");
                return { id: line.slice(0, tab), text: line.slice(tab + 1) };
            })
            .filter(item => isId(item.id));
    }

    property Process watcher: Process {
        running: Settings.clipboardEnabled
        command: ["wl-paste", "--watch", "cliphist", "store"]
    }

    property Process listing: Process {
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: root.items = root.parse(this.text)
        }
    }

    property Process action: Process {}

    property Timer timer: Timer {
        interval: 2000
        running: Settings.clipboardEnabled
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
