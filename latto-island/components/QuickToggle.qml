import QtQuick
import "../theme"

// A round quick-toggle with a label underneath. `checked` fills it with
// `tint`; without `checkable` it acts as a one-shot action button.
Item {
    id: root

    signal clicked()

    property string icon: ""
    property string label: ""
    property bool checked: false
    property bool checkable: true
    property bool available: true
    property color tint: Theme.accent

    readonly property bool lit: checkable && checked

    implicitWidth: 64
    implicitHeight: 56
    opacity: available ? 1 : 0.35

    Accessible.role: checkable ? Accessible.CheckBox : Accessible.Button
    Accessible.name: label
    Accessible.checked: lit

    Rectangle {
        id: disc
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: 38
        height: 38
        radius: 19
        color: root.lit ? root.tint : mouse.containsMouse ? Theme.surfaceRaised : Theme.surface
        border.color: root.lit ? "transparent" : Theme.border
        border.width: 1
        scale: mouse.pressed ? 0.88 : 1

        Behavior on color { ColorAnimation { duration: Theme.fadeDuration } }
        Behavior on scale {
            NumberAnimation { duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve }
        }

        Icon {
            anchors.centerIn: parent
            name: root.icon
            size: 17
            color: root.lit ? Theme.island : Theme.text
            Behavior on color { ColorAnimation { duration: Theme.fadeDuration } }
        }
    }

    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: disc.bottom
        anchors.topMargin: 4
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: root.label
        color: root.lit ? Theme.text : Theme.textSecondary
        font.pixelSize: Theme.fontCaption
        font.weight: Font.Medium
        elide: Text.ElideRight
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.available
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
