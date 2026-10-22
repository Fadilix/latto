import QtQuick
import Quickshell
import "../services"
import "../theme"

// Content of the collapsed island. `mode` picks one layout, and layouts
// cross-fade with a small scale so the change reads as a morph:
//   idle  - status indicators (or the date) on the left, clock on the right
//   media - album art, title and an equaliser
//   alert - the highest-priority entry from Activities
Item {
    id: root

    property string mode: "idle"
    readonly property var alert: Activities.current

    // Animated by IslandWindow when the row hands over to the expanded view
    // or a notification banner.
    property real blur: 0
    layer.enabled: blur > 0.01
    layer.effect: BlurEffect { amount: root.blur }

    // Icon and tint for each alert kind.
    readonly property var alertStyles: ({
        volume: { icon: "volume", color: Theme.text },
        brightness: { icon: "brightness", color: Theme.yellow },
        charging: { icon: "bolt", color: Theme.green },
        lowBattery: { icon: "batteryAlert", color: Theme.red },
        bluetooth: { icon: "bluetooth", color: Theme.blue },
        capsLock: { icon: "capsLock", color: Theme.text },
        timerDone: { icon: "timer", color: Theme.orange },
        dnd: { icon: "moon", color: Theme.indigo }
    })
    // Microphone and camera alerts change look with on/off (data.off).
    readonly property var alertStyle: {
        if (!alert)
            return { icon: "", color: Theme.text };
        const off = alert.data.off === true;
        switch (alert.kind) {
        case "microphone":
            return off ? { icon: "micOff", color: Theme.red } : { icon: "mic", color: Theme.green };
        case "microphoneUse":
            return { icon: "mic", color: off ? Theme.textSecondary : Theme.orange };
        case "camera":
            return off ? { icon: "cameraOff", color: Theme.textSecondary } : { icon: "camera", color: Theme.green };
        case "wifi":
            return off ? { icon: "wifiOff", color: Theme.textSecondary } : { icon: "wifi", color: Theme.blue };
        case "bluetoothPower":
            return { icon: "bluetooth", color: off ? Theme.textSecondary : Theme.blue };
        case "nightLight":
            return { icon: "nightLight", color: off ? Theme.textSecondary : Theme.orange };
        case "pomodoro":
            return { icon: "focus", color: alert.data.phase === "focus" ? Theme.red : Theme.green };
        }
        return alertStyles[alert.kind] || { icon: "", color: Theme.text };
    }
    readonly property bool alertHasValue: alert ? alert.data.value >= 0 : false
    readonly property real alertValue: alertHasValue ? alert.data.value : 0

    readonly property bool microphoneShown: Settings.privacyIndicators && Privacy.microphone
    readonly property bool recordingShown: Settings.privacyIndicators && Privacy.recording
    readonly property bool cameraShown: Settings.privacyIndicators && Privacy.camera
    // Red while a Pomodoro focus runs, green during its breaks.
    readonly property color timerColor: !Timers.pomodoro ? Theme.orange
        : Timers.phase === "focus" ? Theme.red
        : Theme.green
    readonly property bool hasIndicators: Media.playing || microphoneShown || cameraShown || recordingShown
        || Caffeine.active || Timers.timerRunning || Downloads.count > 0 || Notifications.doNotDisturb

    // Shared blur-replace for each layout: the leaving layout blurs, fades and
    // shrinks while the arriving one sharpens in.
    component Layer: Item {
        id: layout

        property bool shown: false
        property real blur: shown ? 0 : Theme.swapBlur

        anchors.fill: parent
        opacity: shown ? 1 : 0
        scale: shown ? 1 : 0.9
        visible: opacity > 0
        layer.enabled: blur > 0.01
        layer.effect: BlurEffect { amount: layout.blur }

        Behavior on opacity {
            NumberAnimation { duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.smoothCurve }
        }
        Behavior on scale {
            NumberAnimation { duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve }
        }
        Behavior on blur {
            NumberAnimation { duration: Theme.swapDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.smoothCurve }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Layer {
        shown: root.mode === "idle"

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 15
            anchors.verticalCenter: parent.verticalCenter
            spacing: 9

            Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.hasIndicators
                text: Qt.formatDateTime(clock.date, "ddd d")
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSmall
                font.weight: Font.Medium
            }
            // Music playing; takes the date's place. The note sways to a beat
            // and a small equaliser bounces beside it.
            Row {
                anchors.verticalCenter: parent.verticalCenter
                visible: Media.playing
                spacing: 5

                Icon {
                    id: musicNote
                    anchors.verticalCenter: parent.verticalCenter
                    name: "music"
                    size: 14
                    color: Theme.accent
                    transformOrigin: Item.Bottom

                    SequentialAnimation {
                        running: musicNote.visible && Media.playing
                        loops: Animation.Infinite
                        onRunningChanged: if (!running) { musicNote.scale = 1; musicNote.rotation = 0; }

                        ParallelAnimation {
                            NumberAnimation { target: musicNote; property: "scale"; to: 1.16; duration: 260; easing.type: Easing.OutQuad }
                            NumberAnimation { target: musicNote; property: "rotation"; to: -10; duration: 260; easing.type: Easing.OutQuad }
                        }
                        ParallelAnimation {
                            NumberAnimation { target: musicNote; property: "scale"; to: 1; duration: 340; easing.type: Easing.InOutQuad }
                            NumberAnimation { target: musicNote; property: "rotation"; to: 0; duration: 340; easing.type: Easing.InOutQuad }
                        }
                        ParallelAnimation {
                            NumberAnimation { target: musicNote; property: "scale"; to: 1.16; duration: 260; easing.type: Easing.OutQuad }
                            NumberAnimation { target: musicNote; property: "rotation"; to: 10; duration: 260; easing.type: Easing.OutQuad }
                        }
                        ParallelAnimation {
                            NumberAnimation { target: musicNote; property: "scale"; to: 1; duration: 340; easing.type: Easing.InOutQuad }
                            NumberAnimation { target: musicNote; property: "rotation"; to: 0; duration: 340; easing.type: Easing.InOutQuad }
                        }
                    }
                }
                Visualizer {
                    anchors.verticalCenter: parent.verticalCenter
                    bars: 3
                    height: 11
                    active: Media.playing
                }
            }
            // Do Not Disturb, with how many notifications are waiting.
            Row {
                anchors.verticalCenter: parent.verticalCenter
                visible: Notifications.doNotDisturb
                spacing: 4

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "moon"
                    size: 13
                    color: Theme.indigo
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Notifications.count > 0
                    text: Notifications.count
                    color: Theme.indigo
                    font.pixelSize: Theme.fontSmall
                    font.weight: Font.DemiBold
                }
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.microphoneShown
                name: "mic"
                size: 14
                color: Theme.orange
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.cameraShown
                name: "camera"
                size: 14
                color: Theme.green
            }
            Rectangle {
                id: recordingDot
                anchors.verticalCenter: parent.verticalCenter
                visible: root.recordingShown
                width: 8
                height: 8
                radius: 4
                color: Theme.red

                SequentialAnimation on opacity {
                    running: recordingDot.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                }
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: Caffeine.active
                name: "coffee"
                size: 14
                color: Theme.yellow
            }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                visible: Timers.timerRunning
                spacing: 4

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Timers.pomodoro ? "focus" : "timer"
                    size: 13
                    color: root.timerColor
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Timers.countdownText
                    color: root.timerColor
                    font.pixelSize: Theme.fontSmall
                    font.weight: Font.DemiBold
                }
            }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                visible: Downloads.count > 0
                spacing: 3

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "download"
                    size: 13
                    color: Theme.cyan
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Downloads.count
                    color: Theme.cyan
                    font.pixelSize: Theme.fontSmall
                    font.weight: Font.DemiBold
                }
            }
        }

        Label {
            anchors.right: parent.right
            anchors.rightMargin: 15
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            font.pixelSize: Theme.fontBody
            font.weight: Font.DemiBold
        }
    }

    Layer {
        shown: root.mode === "media"

        RoundedImage {
            id: smallArt
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            height: 24
            radius: 8
            source: Media.art
        }
        Label {
            anchors.left: smallArt.right
            anchors.leftMargin: 10
            anchors.right: privacyDots.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: Media.title
            font.pixelSize: Theme.fontSmall + 1
            font.weight: Font.Medium
            elide: Text.ElideRight
        }
        // Microphone (orange) and camera (green) in use, as small dots.
        Row {
            id: privacyDots
            anchors.right: visualizer.left
            anchors.rightMargin: visible ? 10 : 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            visible: root.microphoneShown || root.cameraShown

            Rectangle {
                visible: root.microphoneShown
                width: 7
                height: 7
                radius: 3.5
                color: Theme.orange
            }
            Rectangle {
                visible: root.cameraShown
                width: 7
                height: 7
                radius: 3.5
                color: Theme.green
            }
        }
        Visualizer {
            id: visualizer
            anchors.right: parent.right
            anchors.rightMargin: 15
            anchors.verticalCenter: parent.verticalCenter
            active: Media.playing
        }
    }

    // Claude Code live activity: what the session is doing, and for how long.
    Layer {
        id: claudeLayer

        shown: root.mode === "claude"

        readonly property var session: Claude.current
        readonly property bool waiting: session ? session.state === "input" : false
        property real now: Date.now()

        Timer {
            interval: 1000
            repeat: true
            running: claudeLayer.shown
            triggeredOnStart: true
            onTriggered: claudeLayer.now = Date.now()
        }

        Item {
            id: claudeMark
            anchors.left: parent.left
            anchors.leftMargin: 15
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16

            Spinner {
                anchors.fill: parent
                visible: !claudeLayer.waiting
                running: claudeLayer.shown
                size: 16
                color: Theme.claude
            }
            Rectangle {
                id: waitingDot
                anchors.centerIn: parent
                visible: claudeLayer.waiting
                width: 10
                height: 10
                radius: 5
                color: Theme.claude

                SequentialAnimation on scale {
                    running: waitingDot.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: 1.35; duration: 600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
                }
            }
        }

        Label {
            id: claudeProject
            anchors.left: claudeMark.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, parent.width * 0.32)
            text: claudeLayer.session
                ? (claudeLayer.session.project || "Claude") + (Claude.count > 1 ? " +" + (Claude.count - 1) : "")
                : ""
            font.pixelSize: Theme.fontSmall + 1
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Label {
            anchors.left: claudeProject.right
            anchors.leftMargin: 7
            anchors.right: claudeStatus.left
            anchors.rightMargin: 10
            // Smaller text than the project: share its baseline, not its centre.
            anchors.baseline: claudeProject.baseline
            text: claudeLayer.session ? claudeLayer.session.detail : ""
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSmall
            elide: Text.ElideRight
        }
        Label {
            id: claudeStatus
            anchors.right: parent.right
            anchors.rightMargin: 15
            anchors.baseline: claudeProject.baseline
            // Matches Claude Code's own line: "2m 10s · ↓ 9.3k".
            text: claudeLayer.waiting ? "Needs input"
                : claudeLayer.session
                    ? [Claude.elapsedText(claudeLayer.now - claudeLayer.session.startedAt),
                       Claude.tokensText(claudeLayer.session.tokens)].filter(part => part !== "").join("  \u00B7  ")
                : ""
            color: claudeLayer.waiting ? Theme.claude : Theme.textSecondary
            font.pixelSize: Theme.fontSmall
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
    }

    Layer {
        shown: root.mode === "alert"

        Icon {
            id: alertIcon
            anchors.left: parent.left
            anchors.leftMargin: 15
            anchors.verticalCenter: parent.verticalCenter
            name: root.alert && root.alert.kind === "volume" && root.alertValue === 0 ? "volumeOff" : root.alertStyle.icon
            size: 16
            color: root.alertStyle.color
        }
        Label {
            id: alertLabel
            anchors.left: alertIcon.right
            anchors.leftMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            // An explicit width, not a right anchor toggled on and off: once an
            // anchor has stretched an item, removing it leaves the stretched
            // width behind, which squeezed the bar away after a text-only alert.
            width: root.alertHasValue
                ? Math.min(implicitWidth, parent.width * 0.4)
                : parent.width - x - 15
            text: root.alert ? root.alert.data.label : ""
            font.pixelSize: Theme.fontSmall + 1
            font.weight: Font.Medium
            elide: Text.ElideRight
        }
        IslandBar {
            visible: root.alertHasValue
            anchors.left: alertLabel.right
            anchors.leftMargin: 12
            anchors.right: alertPercent.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            value: root.alertValue
            fillColor: root.alertStyle.color
        }
        Label {
            id: alertPercent
            visible: root.alertHasValue
            anchors.right: parent.right
            anchors.rightMargin: 15
            anchors.baseline: alertLabel.baseline
            width: 34
            horizontalAlignment: Text.AlignRight
            text: Math.round(root.alertValue * 100)
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSmall
            font.weight: Font.DemiBold
        }

        // The icon pops each time a new alert replaces the previous one.
        SequentialAnimation {
            id: alertPop
            NumberAnimation { target: alertIcon; property: "scale"; to: 0.6; duration: 0 }
            NumberAnimation { target: alertIcon; property: "scale"; to: 1; duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve }
        }
    }

    onAlertChanged: if (alert) alertPop.restart()
}
