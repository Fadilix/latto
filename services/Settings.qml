pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// User configuration from ~/.config/latto/config.json. Any key that is missing
// keeps its default, so the file can be partial. Changes are picked up live.
FileView {
    id: file

    path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/latto/config.json"
    watchChanges: true
    onFileChanged: reload()

    JsonAdapter {
        id: adapter

        // Empty means the system's default Qt font.
        property string fontFamily: ""
        property string accentColor: "#0a84ff"
        property bool hoverToExpand: true
        // Hide the island over fullscreen windows; notifications still show.
        property bool hideInFullscreen: true
        // The song shows for nowPlayingDuration ms when playback starts or the
        // track changes. Set mediaAlwaysShown to keep it up while playing.
        property bool mediaAlwaysShown: false
        property int nowPlayingDuration: 4000
        // Claude Code live activity (fed by the hooks install.sh sets up).
        property bool claudeActivity: true
        // How long "needs input" stays on the island, in ms.
        property int claudeInputDuration: 10000
        // Pomodoro lengths in minutes; a long break follows every
        // pomodoroRounds focus sessions. Focus sessions turn on Do Not
        // Disturb when pomodoroDnd is set.
        property int pomodoroFocusMinutes: 25
        property int pomodoroBreakMinutes: 5
        property int pomodoroLongBreakMinutes: 15
        property int pomodoroRounds: 4
        property bool pomodoroDnd: true
        // Night light colour temperature in kelvin.
        property int nightLightTemperature: 4500
        // Expanded-view tabs, in display order. Valid names: media,
        // notifications, stats, timers, clipboard, calendar, overview.
        property var tabs: ["media", "notifications", "stats", "timers", "clipboard", "calendar", "overview"]
        // Run latto's own notification daemon. Turn off to keep another one.
        property bool notificationsEnabled: true
        property int notificationDuration: 5000
        // Critical notifications still pop up during Do Not Disturb.
        property bool dndAllowCritical: true
        // No banner for notifications from the app you're already using (its
        // window is focused); they still go to the history.
        property bool quietWhenFocused: true
        property int lowBatteryPercent: 15
        property int hudDuration: 1500
        property int statsInterval: 2000
        property bool showLyrics: true
        property bool clipboardEnabled: true
        property bool calendarEnabled: false
        property real weatherLatitude: 0
        property real weatherLongitude: 0
        property bool privacyIndicators: true
        property bool capsLockIndicator: true
        property bool bluetoothAlerts: true
        property bool timerSound: true
        property string timerSoundFile: "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
    }

    readonly property alias fontFamily: adapter.fontFamily
    readonly property alias accentColor: adapter.accentColor
    readonly property alias hoverToExpand: adapter.hoverToExpand
    readonly property alias hideInFullscreen: adapter.hideInFullscreen
    readonly property alias mediaAlwaysShown: adapter.mediaAlwaysShown
    readonly property alias nowPlayingDuration: adapter.nowPlayingDuration
    readonly property alias claudeActivity: adapter.claudeActivity
    readonly property alias claudeInputDuration: adapter.claudeInputDuration
    readonly property alias pomodoroFocusMinutes: adapter.pomodoroFocusMinutes
    readonly property alias pomodoroBreakMinutes: adapter.pomodoroBreakMinutes
    readonly property alias pomodoroLongBreakMinutes: adapter.pomodoroLongBreakMinutes
    readonly property alias pomodoroRounds: adapter.pomodoroRounds
    readonly property alias pomodoroDnd: adapter.pomodoroDnd
    readonly property alias nightLightTemperature: adapter.nightLightTemperature
    readonly property alias tabs: adapter.tabs
    readonly property alias notificationsEnabled: adapter.notificationsEnabled
    readonly property alias notificationDuration: adapter.notificationDuration
    readonly property alias dndAllowCritical: adapter.dndAllowCritical
    readonly property alias quietWhenFocused: adapter.quietWhenFocused
    readonly property alias lowBatteryPercent: adapter.lowBatteryPercent
    readonly property alias hudDuration: adapter.hudDuration
    readonly property alias statsInterval: adapter.statsInterval
    readonly property alias showLyrics: adapter.showLyrics
    readonly property alias clipboardEnabled: adapter.clipboardEnabled
    readonly property alias calendarEnabled: adapter.calendarEnabled
    readonly property alias weatherLatitude: adapter.weatherLatitude
    readonly property alias weatherLongitude: adapter.weatherLongitude
    readonly property alias privacyIndicators: adapter.privacyIndicators
    readonly property alias capsLockIndicator: adapter.capsLockIndicator
    readonly property alias bluetoothAlerts: adapter.bluetoothAlerts
    readonly property alias timerSound: adapter.timerSound
    readonly property alias timerSoundFile: adapter.timerSoundFile
}
