import QtQuick
import "../theme"

// Rounded panel with an optional caption. Children go in the body below it.
Rectangle {
    id: root

    property string title: ""
    default property alias content: body.data

    radius: Theme.cardRadius
    color: Theme.surface
    border.color: Theme.border
    border.width: 1

    Label {
        id: caption
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.topMargin: root.title !== "" ? 11 : 0
        height: root.title !== "" ? implicitHeight : 0
        visible: root.title !== ""
        text: root.title.toUpperCase()
        color: Theme.textTertiary
        font.pixelSize: Theme.fontCaption
        font.weight: Font.DemiBold
        font.letterSpacing: 0.6
        elide: Text.ElideRight
    }

    Item {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: caption.bottom
        anchors.bottom: parent.bottom
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.topMargin: root.title !== "" ? 6 : 12
        anchors.bottomMargin: 12
    }
}
