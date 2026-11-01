import QtQuick
import "../theme"

// Decorative equaliser bars that bounce while `active` and rest when paused.
Row {
    id: root

    property bool active: false
    property color color: Theme.accent
    property int bars: 4
    readonly property real restLevel: 0.25

    spacing: 2.5
    height: 14

    function randomize() {
        for (let i = 0; i < bars; i++) {
            const bar = repeater.itemAt(i);
            if (bar)
                bar.level = active ? 0.25 + Math.random() * 0.75 : restLevel;
        }
    }

    onActiveChanged: randomize()

    Repeater {
        id: repeater
        model: root.bars

        Rectangle {
            property real level: root.restLevel

            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: Math.max(width, root.height * level)
            radius: width / 2
            color: root.color

            Behavior on level {
                NumberAnimation { duration: 200; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.smoothCurve }
            }
        }
    }

    Timer {
        interval: 190
        repeat: true
        running: root.active && root.visible
        onTriggered: root.randomize()
    }
}
