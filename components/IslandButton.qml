import QtQuick
import "../theme"

// Round button showing an icon, a text label, or both. Hover tints it, press
// squeezes it. `primary` gives a solid light fill, used for the play button.
Item {
    id: root

    signal clicked()

    property string icon: ""
    property string text: ""
    property real iconSize: 18
    property int fontSize: Theme.fontBody
    property bool primary: false
    property bool subtle: false        // faint fill even when not hovered
    property color color: primary ? Theme.island : Theme.text

    implicitHeight: Math.max(iconSize, label.implicitHeight) + 14
    implicitWidth: text === "" ? implicitHeight : content.implicitWidth + 26

    scale: mouse.pressed ? 0.88 : 1
    Behavior on scale {
        NumberAnimation { duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve }
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.text
        opacity: root.primary ? (mouse.containsMouse ? 0.88 : 1)
            : mouse.pressed ? 0.18
            : mouse.containsMouse ? 0.1
            : root.subtle ? 0.06 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.fadeDuration } }
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 6

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            name: root.icon
            size: root.iconSize
            color: root.color
        }
        Label {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            visible: root.text !== ""
            text: root.text
            color: root.color
            font.pixelSize: root.fontSize
            font.weight: Font.Medium
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
