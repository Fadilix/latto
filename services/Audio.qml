pragma Singleton

import QtQuick
import Quickshell.Services.Pipewire

// Default output volume and mute state, and the default microphone's mute
// state, via PipeWire.
QtObject {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false

    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool hasMicrophone: !!(source && source.audio)
    readonly property bool microphoneMuted: hasMicrophone ? source.audio.muted : false

    function setVolume(value) {
        if (sink && sink.audio)
            sink.audio.volume = Math.max(0, Math.min(1, value));
    }

    function toggleMute() {
        if (sink && sink.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    function toggleMicrophone() {
        if (hasMicrophone)
            source.audio.muted = !source.audio.muted;
    }

    // Binding the nodes is required before their audio properties are valid.
    property PwObjectTracker tracker: PwObjectTracker {
        objects: [root.sink, root.source]
    }
}
