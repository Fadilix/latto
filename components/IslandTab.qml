import QtQuick
import "../theme"

// One icon segment of the expanded view's tab bar. The sliding highlight
// behind the selected segment is drawn by ExpandedView.
Item {
    id: root

    signal activated()

    property string icon: ""
    // The tab's name, for screen readers.
    property string text: ""
    property bool selected: false

    implicitWidth: 44
    implicitHeight: 26

    Accessible.role: Accessible.PageTab
    Accessible.name: text

    Icon {
        anchors.centerIn: parent
        name: root.icon
        size: 15
        color: root.selected ? Theme.text : mouse.containsMouse ? Theme.textSecondary : Theme.textTertiary
        scale: mouse.pressed ? 0.85 : root.selected ? 1.12 : 1

        Behavior on color { ColorAnimation { duration: Theme.fadeDuration } }
        Behavior on scale {
            NumberAnimation { duration: 360; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
