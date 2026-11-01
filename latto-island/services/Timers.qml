pragma Singleton

import QtQuick
import Quickshell.Io

// Countdown timer, Pomodoro cycle and stopwatch. A plain countdown emits
// finished() when it reaches zero; a Pomodoro phase emits phaseEnded() and
// moves straight on to the next phase.
QtObject {
    id: root

    signal finished()
    // ended and next are "focus", "break" or "longBreak".
    signal phaseEnded(string ended, string next)

    // Countdown (milliseconds). timerRemaining is only live while running.
    property real timerPreset: 0
    property real timerRemaining: 0
    property real timerEndsAt: 0
    property bool timerRunning: false

    // Stopwatch (milliseconds).
    property bool swRunning: false
    property real swBase: 0
    property real swStartedAt: 0
    property real swElapsed: 0

    // Pomodoro. phase is "" when no cycle is running.
    property string phase: ""
    // Focus sessions finished in the current cycle (resets after a long break).
    property int focusDone: 0
    // Whether the cycle turned Do Not Disturb on, so it only turns off what it turned on.
    property bool pomodoroSetDnd: false
    readonly property bool pomodoro: phase !== ""

    readonly property string phaseLabel: phase === "focus" ? "Focus"
        : phase === "break" ? "Short break"
        : phase === "longBreak" ? "Long break"
        : ""

    readonly property string countdownText: formatTime(Math.ceil(timerRemaining / 1000) * 1000, false)
    readonly property string stopwatchText: formatTime(swElapsed, true)

    function formatTime(ms, tenths) {
        const totalTenths = Math.floor(ms / 100);
        const minutes = Math.floor(totalTenths / 600);
        const seconds = Math.floor(totalTenths / 10) % 60;
        const text = String(minutes).padStart(2, "0") + ":" + String(seconds).padStart(2, "0");
        return tenths ? text + "." + (totalTenths % 10) : text;
    }

    function setPreset(ms) {
        timerPreset = ms;
        timerRemaining = ms;
        timerRunning = false;
    }

    function startTimer() {
        if (timerRemaining <= 0)
            return;
        timerEndsAt = Date.now() + timerRemaining;
        timerRunning = true;
    }

    function pauseTimer() {
        if (!timerRunning)
            return;
        timerRemaining = Math.max(0, timerEndsAt - Date.now());
        timerRunning = false;
    }

    function resetTimer() {
        if (pomodoro) {
            stopPomodoro();
            return;
        }
        timerRunning = false;
        timerRemaining = timerPreset;
    }

    function phaseMinutes(name) {
        if (name === "focus") return Settings.pomodoroFocusMinutes;
        if (name === "break") return Settings.pomodoroBreakMinutes;
        return Settings.pomodoroLongBreakMinutes;
    }

    function startPomodoro() {
        focusDone = 0;
        beginPhase("focus");
    }

    function beginPhase(name) {
        phase = name;
        setPreset(phaseMinutes(name) * 60000);
        startTimer();
        updateDnd();
    }

    // Ends the current phase early and starts the next one.
    function skipPhase() {
        if (pomodoro)
            advance();
    }

    function stopPomodoro() {
        phase = "";
        focusDone = 0;
        timerRunning = false;
        timerPreset = 0;
        timerRemaining = 0;
        updateDnd();
    }

    function advance() {
        const ended = phase;
        let next = "focus";
        if (ended === "focus") {
            focusDone++;
            next = focusDone % Math.max(1, Settings.pomodoroRounds) === 0 ? "longBreak" : "break";
        } else if (ended === "longBreak") {
            focusDone = 0;
        }
        phaseEnded(ended, next);
        beginPhase(next);
    }

    // Do Not Disturb during focus, if wanted. Never turns off a Do Not
    // Disturb the user switched on themselves.
    function updateDnd() {
        const want = Settings.pomodoroDnd && phase === "focus";
        if (want && !Notifications.doNotDisturb) {
            Notifications.setDoNotDisturb(true);
            pomodoroSetDnd = true;
        } else if (!want && pomodoroSetDnd) {
            pomodoroSetDnd = false;
            Notifications.setDoNotDisturb(false);
        }
    }

    function playSound() {
        if (Settings.timerSound) {
            sound.command = ["paplay", Settings.timerSoundFile];
            sound.running = true;
        }
    }

    function toggleStopwatch() {
        if (swRunning) {
            swBase = swElapsed;
            swRunning = false;
        } else {
            swStartedAt = Date.now();
            swRunning = true;
        }
    }

    function resetStopwatch() {
        swRunning = false;
        swBase = 0;
        swElapsed = 0;
    }

    onFinished: playSound()
    onPhaseEnded: playSound()

    property Process sound: Process {}

    property Timer tick: Timer {
        interval: 200
        repeat: true
        running: root.timerRunning || root.swRunning
        onTriggered: {
            const now = Date.now();
            if (root.timerRunning) {
                const left = root.timerEndsAt - now;
                if (left <= 0) {
                    root.timerRemaining = 0;
                    root.timerRunning = false;
                    if (root.pomodoro)
                        root.advance();
                    else
                        root.finished();
                } else {
                    root.timerRemaining = left;
                }
            }
            if (root.swRunning)
                root.swElapsed = root.swBase + (now - root.swStartedAt);
        }
    }
}
