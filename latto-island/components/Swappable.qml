import QtQuick
import "../theme"

// One of two views sharing a space (a grid and a list behind it). Switching
// is a blur-replace: the leaving view blurs, fades and shrinks while the
// arriving one sharpens in.
Item {
    id: root

    property bool shown: true
    property real blur: shown ? 0 : Theme.swapBlur

    opacity: shown ? 1 : 0
    scale: shown ? 1 : 0.96
    visible: opacity > 0.01
    layer.enabled: blur > 0.01
    layer.effect: BlurEffect { amount: root.blur }

    Behavior on opacity {
        NumberAnimation { duration: 240; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.smoothCurve }
    }
    Behavior on scale {
        NumberAnimation { duration: 380; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve }
    }
    Behavior on blur {
        NumberAnimation { duration: Theme.swapDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.smoothCurve }
    }
}
