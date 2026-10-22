pragma Singleton

import QtQuick
import Quickshell.Services.Mpris

// The most relevant MPRIS player (a playing one first, otherwise any) and its controls.
QtObject {
    id: root

    readonly property var player: {
        let fallback = null;
        for (const candidate of Mpris.players.values) {
            if (candidate.isPlaying)
                return candidate;
            if (!fallback)
                fallback = candidate;
        }
        return fallback;
    }

    readonly property bool playing: player ? player.isPlaying : false
    readonly property string title: player ? (player.trackTitle || "Unknown title") : ""
    readonly property string artist: player ? player.trackArtist : ""
    readonly property string album: player ? player.trackAlbum : ""
    readonly property string art: player ? player.trackArtUrl : ""
    readonly property string source: player ? player.identity : ""
    readonly property real length: player && player.lengthSupported ? player.length : 0
    readonly property bool shuffle: player ? player.shuffle : false
    readonly property bool shuffleSupported: player ? player.shuffleSupported : false

    // Seconds. MPRIS does not push position updates, so refreshPosition() polls.
    property real position: 0
    readonly property real progress: length > 0 ? Math.min(1, position / length) : 0

    onTitleChanged: refreshPosition()

    function refreshPosition() {
        if (!player)
            return;
        player.positionChanged();
        position = player.position;
    }

    property Timer positionTimer: Timer {
        interval: 500
        repeat: true
        running: root.playing
        triggeredOnStart: true
        onTriggered: root.refreshPosition()
    }

    function toggle() {
        if (player && player.canTogglePlaying)
            player.togglePlaying();
    }

    function next() {
        if (player && player.canGoNext)
            player.next();
    }

    function previous() {
        if (player && player.canGoPrevious)
            player.previous();
    }

    // fraction is 0..1 along the track.
    function seek(fraction) {
        if (player && player.canSeek && length > 0) {
            player.position = Math.max(0, Math.min(1, fraction)) * length;
            refreshPosition();
        }
    }

    function toggleShuffle() {
        if (player && player.shuffleSupported)
            player.shuffle = !player.shuffle;
    }
}
