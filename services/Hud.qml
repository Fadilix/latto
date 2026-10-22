pragma Singleton

import QtQuick

// Turns hardware and session changes into island alerts. Nothing fires during
// the first two seconds, so state that already exists does not flash on start.
QtObject {
    id: root

    property bool armed: false

    property Timer armTimer: Timer {
        interval: 2000
        running: true
        onTriggered: root.armed = true
    }

    function showVolume() {
        const value = Audio.muted ? 0 : Audio.volume;
        Activities.show("volume", 70, { label: "Volume", value: value }, Settings.hudDuration);
    }

    function showBrightness() {
        Activities.show("brightness", 70, { label: "Brightness", value: Brightness.level }, Settings.hudDuration);
    }

    property Connections audioWatch: Connections {
        target: Audio
        function onVolumeChanged() {
            if (root.armed) root.showVolume();
        }
        function onMutedChanged() {
            if (root.armed) root.showVolume();
        }
    }

    property Connections brightnessWatch: Connections {
        target: Brightness
        function onLevelChanged() {
            if (root.armed && Brightness.available) root.showBrightness();
        }
    }

    property Connections batteryWatch: Connections {
        target: Battery
        function onChargingChanged() {
            if (!root.armed || !Battery.available) return;
            if (Battery.charging) {
                Activities.dismiss("lowBattery");
                Activities.show("charging", 60, { label: "Charging " + Battery.percent + "%", value: -1 }, 3500);
            }
        }
        function onPercentChanged() {
            const low = Battery.available && !Battery.charging && Battery.percent <= Settings.lowBatteryPercent;
            if (root.armed && low)
                Activities.show("lowBattery", 100, { label: "Low battery " + Battery.percent + "%", value: -1 }, 12000);
        }
    }

    property Connections capsLockWatch: Connections {
        target: CapsLock
        function onActiveChanged() {
            if (!root.armed || !Settings.capsLockIndicator) return;
            if (CapsLock.active)
                Activities.show("capsLock", 50, { label: "Caps Lock on", value: -1 }, 0);
            else
                Activities.dismiss("capsLock");
        }
    }

    // Muting or unmuting the microphone, from any app or key.
    property Connections microphoneMuteWatch: Connections {
        target: Audio
        function onMicrophoneMutedChanged() {
            if (!root.armed || !Audio.hasMicrophone) return;
            if (Audio.microphoneMuted)
                Activities.show("microphone", 75, { label: "Microphone off", value: -1, off: true }, 1800);
            else
                Activities.show("microphone", 75, { label: "Microphone on", value: -1, off: false }, 1800);
        }
    }

    // An app starting or stopping use of the microphone or camera.
    property Connections privacyWatch: Connections {
        target: Privacy
        function onMicrophoneChanged() {
            if (!root.armed || !Settings.privacyIndicators) return;
            Activities.show("microphoneUse", 74,
                { label: Privacy.microphone ? "Microphone in use" : "Microphone no longer in use", value: -1, off: !Privacy.microphone },
                2200);
        }
        function onCameraChanged() {
            if (!root.armed || !Settings.privacyIndicators) return;
            Activities.show("camera", 76,
                { label: Privacy.camera ? "Camera on" : "Camera off", value: -1, off: !Privacy.camera },
                2200);
        }
    }

    // Playback starting, or a new track while playing, shows the song for a
    // moment; then the island returns to idle. With mediaAlwaysShown the media
    // view stays up the whole time instead (handled by IslandWindow).
    function showNowPlaying() {
        if (!root.armed || Settings.mediaAlwaysShown)
            return;
        Activities.show("nowPlaying", 40, { label: Media.title, value: -1 }, Settings.nowPlayingDuration);
    }

    property Connections mediaWatch: Connections {
        target: Media
        function onPlayingChanged() {
            if (Media.playing)
                root.showNowPlaying();
            else
                Activities.dismiss("nowPlaying");
        }
        function onTitleChanged() {
            if (Media.playing)
                root.showNowPlaying();
        }
    }

    property Connections timerWatch: Connections {
        target: Timers
        function onFinished() {
            Activities.show("timerDone", 90, { label: "Timer finished", value: -1 }, 15000);
        }
        function onPhaseEnded(ended, next) {
            const label = next === "focus"
                ? "Break over · focus for " + Timers.phaseMinutes("focus") + " min"
                : "Focus done · " + Timers.phaseMinutes(next) + " min " + (next === "longBreak" ? "long break" : "break");
            Activities.show("pomodoro", 90, { label: label, value: -1, phase: next }, 6000);
        }
    }

    // One watcher per Bluetooth device, so each connect or disconnect is reported.
    property Instantiator bluetoothWatch: Instantiator {
        model: Bluetooth.devices
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectedChanged() {
                if (!root.armed || !Settings.bluetoothAlerts) return;
                const name = modelData.name || modelData.deviceName;
                const verb = modelData.connected ? "Connected" : "Disconnected";
                Activities.show("bluetooth", 80, { label: verb + ": " + name, value: -1 }, 2500);
            }
        }
    }
}
