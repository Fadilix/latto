import QtQuick
import "../services"
import "../theme"

// One entry in the Notifications tab: icon, app and age, summary, body, and
// the app's action buttons. Click runs the default action; the cross dismisses.
Rectangle {
    id: root

    required property var notification
    property real now: Date.now()

    readonly property bool critical: Notifications.isCritical(notification)
    readonly property var actions: Notifications.buttonActions(notification)

    implicitHeight: content.implicitHeight + 24
    radius: 16
    color: hover.hovered ? Theme.surfaceRaised : Theme.surface
    border.color: critical ? Qt.rgba(Theme.red.r, Theme.red.g, Theme.red.b, 0.5) : Theme.border
    border.width: 1
    Behavior on color { ColorAnimation { duration: Theme.fadeDuration } }

    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Notifications.defaultAction(root.notification) ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (Notifications.defaultAction(root.notification))
                Notifications.activate(root.notification);
        }
    }

    NotificationIcon {
        id: icon
        x: 12
        y: 12
        width: 34
        height: 34
        radius: 11
        notification: root.notification
        tint: root.critical ? Theme.red : Theme.accent
    }

    Column {
        id: content
        anchors.left: icon.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 12
        y: 12
        spacing: 2

        Item {
            width: parent.width
            height: appLine.implicitHeight

            Label {
                id: appLine
                anchors.left: parent.left
                anchors.right: closeButton.left
                anchors.rightMargin: 6
                text: (root.notification.appName || "Notification") + "  ·  " + Notifications.age(root.notification, root.now)
                color: root.critical ? Theme.red : Theme.textTertiary
                font.pixelSize: Theme.fontCaption
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            IslandButton {
                id: closeButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                opacity: hover.hovered ? 1 : 0
                icon: "close"
                iconSize: 11
                color: Theme.textSecondary
                onClicked: root.notification.dismiss()
                Behavior on opacity { NumberAnimation { duration: Theme.fadeDuration } }
            }
        }
        Label {
            width: parent.width
            text: root.notification.summary
            font.pixelSize: Theme.fontBody
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Label {
            width: parent.width
            visible: text !== ""
            text: Notifications.plainText(root.notification.body)
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSmall + 1
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }
        Flow {
            width: parent.width
            visible: root.actions.length > 0
            topPadding: 6
            spacing: 6

            Repeater {
                model: root.actions
                IslandButton {
                    required property var modelData
                    text: modelData.text
                    fontSize: Theme.fontSmall
                    subtle: true
                    onClicked: modelData.invoke()
                }
            }
        }
    }
}
