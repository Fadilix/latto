import QtQuick
import "../../services"
import "../../theme"
import ".."

// Clipboard history. Click an entry to copy it again; the cross deletes it.
Item {
    id: root

    // Entry that was just copied, shown with a check mark for a moment.
    property string copiedId: ""

    Timer {
        id: copiedReset
        interval: 1200
        onTriggered: root.copiedId = ""
    }

    Label {
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: clearButton.verticalCenter
        text: Clipboard.items.length + (Clipboard.items.length === 1 ? " item" : " items")
        color: Theme.textTertiary
        font.pixelSize: Theme.fontSmall
        font.weight: Font.Medium
    }
    IslandButton {
        id: clearButton
        anchors.right: parent.right
        anchors.top: parent.top
        visible: Clipboard.items.length > 0
        text: "Clear all"
        fontSize: Theme.fontSmall
        subtle: true
        onClicked: Clipboard.clear()
    }

    Column {
        anchors.centerIn: list
        spacing: 8
        visible: Clipboard.items.length === 0

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: "copy"
            size: 26
            color: Theme.textTertiary
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Settings.clipboardEnabled ? "Copied text shows up here" : "Clipboard history is off"
            color: Theme.textSecondary
        }
    }

    ListView {
        id: list
        anchors.top: clearButton.bottom
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        spacing: 2
        model: Clipboard.items
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: entry

            required property var modelData
            readonly property bool copied: root.copiedId === modelData.id

            width: ListView.view.width
            height: 32
            radius: 10
            color: copied ? Qt.rgba(Theme.green.r, Theme.green.g, Theme.green.b, 0.14)
                : rowHover.hovered ? Theme.surface : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.fadeDuration } }

            // Stays hovered over the delete button too, unlike a MouseArea.
            HoverHandler {
                id: rowHover
            }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Clipboard.copy(entry.modelData.id);
                    root.copiedId = entry.modelData.id;
                    copiedReset.restart();
                }
            }

            Label {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.right: trailing.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: entry.modelData.text
                font.pixelSize: Theme.fontBody - 1
                elide: Text.ElideRight
            }

            Item {
                id: trailing
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 28

                Icon {
                    anchors.centerIn: parent
                    visible: entry.copied
                    name: "check"
                    size: 15
                    color: Theme.green
                }
                IslandButton {
                    anchors.centerIn: parent
                    visible: !entry.copied
                    opacity: rowHover.hovered ? 1 : 0
                    icon: "close"
                    iconSize: 13
                    color: Theme.textSecondary
                    onClicked: Clipboard.remove(entry.modelData.id)
                    Behavior on opacity { NumberAnimation { duration: Theme.fadeDuration } }
                }
            }
        }
    }
}
