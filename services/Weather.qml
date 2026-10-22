pragma Singleton

import QtQuick
import Quickshell.Io

// Current weather from Open-Meteo. Enabled once weatherLatitude or
// weatherLongitude is set in the config. Coordinates are sent to Open-Meteo.
QtObject {
    id: root

    readonly property bool enabled: Settings.weatherLatitude !== 0 || Settings.weatherLongitude !== 0
    readonly property string url: "https://api.open-meteo.com/v1/forecast?latitude=" + Settings.weatherLatitude
        + "&longitude=" + Settings.weatherLongitude + "&current=temperature_2m,weather_code"

    property string temperature: ""
    property string condition: ""

    function describe(code) {
        if (code === 0) return "Clear";
        if (code <= 3) return "Partly cloudy";
        if (code <= 48) return "Fog";
        if (code <= 57) return "Drizzle";
        if (code <= 67) return "Rain";
        if (code <= 77) return "Snow";
        if (code <= 82) return "Showers";
        if (code <= 99) return "Thunderstorm";
        return "";
    }

    property Process fetcher: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const current = JSON.parse(this.text).current;
                    root.temperature = Math.round(current.temperature_2m) + "°C";
                    root.condition = root.describe(current.weather_code);
                } catch (error) {
                    console.warn("latto: weather unavailable: " + error);
                }
            }
        }
    }

    property Timer timer: Timer {
        interval: 900000
        running: root.enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.fetcher.command = ["curl", "-sf", "--max-time", "10", root.url];
            root.fetcher.running = true;
        }
    }
}
