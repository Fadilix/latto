pragma Singleton

import QtQuick
import Quickshell.Io

// Keep-awake mode: holds a systemd idle inhibitor while active.
QtObject {
    id: root

    property bool active: false

    function toggle() {
        active = !active;
    }

    property Process inhibitor: Process {
        running: root.active
        command: ["systemd-inhibit", "--what=idle", "--who=latto", "--why=Caffeine mode", "sleep", "infinity"]
    }
}
