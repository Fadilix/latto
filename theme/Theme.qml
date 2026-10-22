pragma Singleton

import QtQuick
import "../services"

// Visual constants: font, palette, geometry and motion.
QtObject {
    // The `fontFamily` config key if set, otherwise the system's default Qt
    // font (chosen by qt6ct, KDE or the platform theme).
    readonly property string fontFamily: Settings.fontFamily !== "" ? Settings.fontFamily : Qt.application.font.family

    readonly property int fontCaption: 10
    readonly property int fontSmall: 11
    readonly property int fontBody: 13
    readonly property int fontTitle: 16
    readonly property int fontDisplay: 34

    // Palette
    readonly property color island: "#000000"
    readonly property color surface: "#141416"
    readonly property color surfaceRaised: "#26262a"
    readonly property color border: Qt.rgba(1, 1, 1, 0.08)
    readonly property color text: "#f5f5f7"
    readonly property color textSecondary: "#a1a1a6"
    readonly property color textTertiary: "#636366"
    readonly property color accent: Settings.accentColor
    readonly property color red: "#ff453a"
    readonly property color orange: "#ff9f0a"
    readonly property color yellow: "#ffd60a"
    readonly property color green: "#30d158"
    readonly property color cyan: "#64d2ff"
    readonly property color blue: "#0a84ff"
    readonly property color indigo: "#5e5ce6"
    // Claude's coral, for the Claude Code live activity.
    readonly property color claude: "#d97757"

    // Island geometry
    readonly property int topMargin: 8
    readonly property int compactHeight: 36
    readonly property int idleWidth: 210
    readonly property int activityWidth: 340
    readonly property int expandedWidth: 600
    readonly property int expandedHeight: 276
    readonly property int expandedRadius: 34
    readonly property int notificationWidth: 420
    readonly property int notificationHeight: 76
    readonly property int notificationRadius: 28
    // What the island shrinks to before disappearing in fullscreen.
    readonly property int dotSize: 12
    readonly property int padding: 18
    readonly property int cardRadius: 18

    // Motion. Curves are cubic beziers in the [x1, y1, x2, y2, 1, 1] form that
    // Easing.BezierSpline expects.
    readonly property var springCurve: [0.34, 1.36, 0.64, 1, 1, 1]    // overshoots, then settles
    readonly property var settleCurve: [0.3, 1.12, 0.5, 1, 1, 1]      // gentler overshoot
    readonly property var smoothCurve: [0.32, 0.72, 0, 1, 1, 1]       // quick start, soft landing
    readonly property var exitCurve: [0.4, 0, 1, 1, 1, 1]             // accelerates away

    readonly property int expandDuration: 560
    readonly property int collapseDuration: 460
    readonly property int morphDuration: 480
    readonly property int fadeDuration: 200

    // Blur transitions: hidden content sits blurred and sharpens as it
    // appears. Swaps between views (blur-replace) use a lighter blur.
    readonly property real hiddenBlur: 1.0
    readonly property real swapBlur: 0.55
    readonly property int swapDuration: 340

    // Hover debounce: brushing past does not open, leaving always closes.
    readonly property int hoverOpenDelay: 70
    readonly property int hoverCloseDelay: 240
}
