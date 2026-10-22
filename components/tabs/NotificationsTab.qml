import QtQuick
import Quickshell
import "../../services"
import "../../theme"
import ".."

// Notification history, newest first, with the Do Not Disturb switch.
Item {
    id: root

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Label {
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: header.verticalCenter
        text: Notifications.count === 0 ? "No notifications"
            : Notifications.count + (Notifications.count === 1 ? " notification" : " notifications")
        color: Theme.textTertiary
        font.pixelSize: Theme.fontSmall
        font.weight: Font.Medium
    }

    Row {
        id: header
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 6

        IslandButton {
            visible: Notifications.count > 0
            text: "Clear all"
            fontSize: Theme.fontSmall
            subtle: true
            onClicked: Notifications.clearAll()
        }
        IslandButton {
            icon: "moon"
            iconSize: 13
            text: Notifications.doNotDisturb ? "Do Not Disturb on" : "Do Not Disturb"
            fontSize: Theme.fontSmall
            subtle: true
            color: Notifications.doNotDisturb ? Theme.indigo : Theme.textSecondary
            onClicked: Notifications.toggleDoNotDisturb()
        }
    }

    Column {
        anchors.centerIn: list
        spacing: 8
        visible: Notifications.count === 0

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: Notifications.doNotDisturb ? "moon" : "bell"
            size: 28
            color: Notifications.doNotDisturb ? Theme.indigo : Theme.textTertiary
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: !Settings.notificationsEnabled ? "latto's notification daemon is off"
                : Notifications.doNotDisturb ? "Do Not Disturb is on" : "You're all caught up"
            color: Theme.textSecondary
        }
    }

    ListView {
        id: list
        anchors.top: header.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        spacing: 6
        model: Notifications.history
        boundsBehavior: Flickable.StopAtBounds

        delegate: NotificationCard {
            required property var modelData
            width: ListView.view.width
            notification: modelData
            now: clock.date.getTime()
        }
    }
}
