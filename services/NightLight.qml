pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Night light through hyprsunset. On means a hyprsunset process is running at
// nightLightTemperature; off resets the screen to its normal colours.
// If ~/.cache/.hyprsunset_state exists (as used by some Hyprland setups'
// Waybar modules), it is kept in step.
QtObject {
    id: root

    property bool active: false
    readonly property string stateFile: Quickshell.env("HOME") + "/.cache/.hyprsunset_state"

    function toggle() {
        setActive(!active);
    }

    function setActive(on) {
        active = on;
        const script = on
            ? "pkill -x hyprsunset; sleep 0.2; setsid -f hyprsunset -t \"$1\" >/dev/null 2>&1; [ -f \"$2\" ] && echo on > \"$2\"; true"
            : "pkill -x hyprsunset; sleep 0.2; setsid -f hyprsunset -i >/dev/null 2>&1; sleep 0.4; pkill -x hyprsunset; [ -f \"$2\" ] && echo off > \"$2\"; true";
        Quickshell.execDetached(["sh", "-c", script, "sh", String(Settings.nightLightTemperature), stateFile]);
        Activities.show("nightLight", 70, { label: on ? "Night light on" : "Night light off", value: -1, off: !on }, 1800);
        recheck.restart();
    }

    property Process probe: Process {
        command: ["pgrep", "-x", "hyprsunset"]
        onExited: code => root.active = code === 0
    }

    // Confirms the state after a toggle settles, and catches changes made
    // elsewhere (a keybind or another bar).
    property Timer recheck: Timer {
        interval: 1200
        onTriggered: root.probe.running = true
    }

    property Timer poll: Timer {
        interval: 5000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.probe.running = true
    }
}
