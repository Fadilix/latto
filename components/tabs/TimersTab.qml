import QtQuick
import "../../services"
import "../../theme"
import ".."

// Countdown timer (with presets, or a Pomodoro cycle) beside a stopwatch.
Row {
    id: root

    spacing: 10

    readonly property real cardWidth: (width - spacing) / 2
    // Red for Pomodoro focus, green for its breaks, orange for a plain timer.
    readonly property color countdownTint: !Timers.pomodoro ? Theme.orange
        : Timers.phase === "focus" ? Theme.red
        : Theme.green

    component Readout: Label {
        anchors.horizontalCenter: parent.horizontalCenter
        font.pixelSize: Theme.fontDisplay
        font.weight: Font.Medium
        font.features: { "tnum": 1 }
    }

    Card {
        width: root.cardWidth
        height: root.height
        title: Timers.pomodoro ? "Pomodoro" : "Countdown"

        Readout {
            id: countdown
            anchors.top: parent.top
            text: Timers.countdownText
            color: Timers.timerRunning ? root.countdownTint : Theme.text
            Behavior on color { ColorAnimation { duration: Theme.fadeDuration } }
        }
        IslandBar {
            id: countdownBar
            anchors.top: countdown.bottom
            anchors.topMargin: 4
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.7
            value: Timers.timerPreset > 0 ? Timers.timerRemaining / Timers.timerPreset : 0
            fillColor: root.countdownTint
        }

        // Presets, plus "Focus" to start a Pomodoro cycle.
        Row {
            anchors.top: countdownBar.bottom
            anchors.topMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            visible: !Timers.pomodoro

            Repeater {
                model: [5, 10, 25]
                IslandButton {
                    required property int modelData
                    text: modelData + "m"
                    fontSize: Theme.fontSmall
                    subtle: true
                    onClicked: Timers.setPreset(modelData * 60000)
                }
            }
            IslandButton {
                icon: "focus"
                iconSize: 12
                text: "Focus"
                fontSize: Theme.fontSmall
                subtle: true
                color: Theme.red
                onClicked: Timers.startPomodoro()
            }
        }

        // During a cycle: the phase, and a dot per focus round.
        Row {
            anchors.top: countdownBar.bottom
            anchors.topMargin: 14
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            visible: Timers.pomodoro

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: Timers.phaseLabel
                color: root.countdownTint
                font.pixelSize: Theme.fontSmall
                font.weight: Font.DemiBold
            }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Repeater {
                    model: Math.max(1, Settings.pomodoroRounds)
                    Rectangle {
                        required property int index
                        readonly property bool done: index < Timers.focusDone % Math.max(1, Settings.pomodoroRounds)
                            || (Timers.phase === "longBreak")
                        readonly property bool current: Timers.phase === "focus"
                            && index === Timers.focusDone % Math.max(1, Settings.pomodoroRounds)

                        width: 7
                        height: 7
                        radius: 3.5
                        color: done ? Theme.red : current ? "transparent" : Theme.surfaceRaised
                        border.color: current ? Theme.red : "transparent"
                        border.width: current ? 1.5 : 0
                    }
                }
            }
        }

        Row {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            IslandButton {
                primary: true
                text: Timers.timerRunning ? "Pause" : Timers.pomodoro ? "Resume" : "Start"
                icon: Timers.timerRunning ? "pause" : "play"
                iconSize: 14
                onClicked: Timers.timerRunning ? Timers.pauseTimer() : Timers.startTimer()
            }
            IslandButton {
                visible: Timers.pomodoro
                subtle: true
                icon: "skip"
                iconSize: 13
                onClicked: Timers.skipPhase()
            }
            IslandButton {
                subtle: true
                text: Timers.pomodoro ? "Stop" : "Reset"
                onClicked: Timers.resetTimer()
            }
        }
    }

    Card {
        width: root.cardWidth
        height: root.height
        title: "Stopwatch"

        Readout {
            anchors.top: parent.top
            text: Timers.stopwatchText
            color: Timers.swRunning ? Theme.green : Theme.text
            Behavior on color { ColorAnimation { duration: Theme.fadeDuration } }
        }
        Row {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            IslandButton {
                primary: true
                text: Timers.swRunning ? "Stop" : "Start"
                icon: Timers.swRunning ? "pause" : "play"
                iconSize: 14
                onClicked: Timers.toggleStopwatch()
            }
            IslandButton {
                subtle: true
                text: "Reset"
                onClicked: Timers.resetStopwatch()
            }
        }
    }
}
