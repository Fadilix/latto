pragma Singleton

import QtQuick
import Quickshell.Io

// Synced lyrics for the current track from lrclib.net. The track title, artist,
// album and duration are sent to that service; disable with showLyrics=false.
QtObject {
    id: root

    // [{ time: seconds, text }], sorted by time
    property var lines: []

    // Index of the line being sung, or -1 before the first line.
    readonly property int currentIndex: {
        let index = -1;
        for (let i = 0; i < lines.length && lines[i].time <= Media.position; i++)
            index = i;
        return index;
    }

    readonly property string currentText: currentIndex >= 0 ? lines[currentIndex].text : ""

    function fetch() {
        lines = [];
        if (!Settings.showLyrics || !Media.title || !Media.artist)
            return;

        const params = [
            "track_name=" + encodeURIComponent(Media.title),
            "artist_name=" + encodeURIComponent(Media.artist),
            "album_name=" + encodeURIComponent(Media.album),
            "duration=" + Math.round(Media.length)
        ];
        // A new track replaces any request still in flight.
        request.running = false;
        request.command = ["curl", "-sf", "--max-time", "8", "https://lrclib.net/api/get?" + params.join("&")];
        request.running = true;
    }

    function parse(synced) {
        const parsed = [];
        for (const line of synced.split("\n")) {
            const match = /^\[(\d+):(\d+(?:\.\d+)?)\]\s*(.*)$/.exec(line.trim());
            if (match)
                parsed.push({ time: Number(match[1]) * 60 + Number(match[2]), text: match[3] });
        }
        return parsed;
    }

    property Process request: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text);
                    root.lines = data.syncedLyrics ? root.parse(data.syncedLyrics) : [];
                } catch (error) {
                    // 404 or offline: no lyrics for this track.
                    root.lines = [];
                }
            }
        }
    }

    property Connections trackWatch: Connections {
        target: Media
        function onTitleChanged() { root.fetch(); }
        function onArtistChanged() { root.fetch(); }
    }
}
