import QtQuick
import QtQuick.Controls
import "../../latto-island/theme"

Rectangle {
    id: root
    property string icon: ""
    property string text: ""
    property string tooltip: ""
    property color tint: Theme.textSecondary
    property bool active: false
    property bool interactive: true
    signal clicked()
    signal secondaryClicked()
    signal scrolled(real delta)
    implicitWidth: content.width + 16
    implicitHeight: 28
    radius: 9
    color: interactive && pointer.containsMouse ? Theme.surfaceRaised : active ? Theme.surface : "transparent"
    Behavior on color { ColorAnimation { duration: 140 } }
    Accessible.role: interactive ? Accessible.Button : Accessible.StaticText
    Accessible.name: tooltip || text || icon
    Accessible.onPressAction: if (interactive) clicked()

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 6
        BarIcon {
            visible: root.icon !== ""
            name: root.icon
            size: 16
            color: root.tint
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            visible: root.text !== ""
            text: root.text
            color: root.tint
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: root.interactive ? Qt.LeftButton | Qt.RightButton : Qt.NoButton
        onClicked: mouse => mouse.button === Qt.RightButton ? root.secondaryClicked() : root.clicked()
        onWheel: wheel => {
            if (root.interactive) root.scrolled(wheel.angleDelta.y);
            else wheel.accepted = false;
        }
    }
    ToolTip {
        parent: root
        visible: pointer.containsMouse && root.tooltip !== ""
        text: root.tooltip
        delay: 650
        timeout: 4500
        padding: 9
        topPadding: 6
        bottomPadding: 6
        y: root.height + 7
        contentItem: Text {
            text: root.tooltip
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.Medium
        }
        background: Rectangle {
            radius: 8
            color: "#19191d"
            border.width: 1
            border.color: Theme.border
        }
        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 120 } }
        exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 80 } }
    }
}
